# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials)
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "wqp-postgres-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-g1-small"
    ip_configuration {
      ipv4_enabled = true
      authorized_networks {
        name  = "cloud-run-network"
        value = "0.0.0.0/0"  # Allows access from any IP (less secure)
      }
    }
  }

  deletion_protection = true
}

# Database for Sensorthings
resource "google_sql_database" "sensorthings" {
  name     = "sensorthings"
  instance = google_sql_database_instance.postgres.name
}

# Database User
resource "google_sql_user" "sensorthings_user" {
  name     = "sensorthings"
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
}

resource "null_resource" "enable_postgis" {

  provisioner "local-exec" {
    command = <<EOT
      export GOOGLE_APPLICATION_CREDENTIALS=${var.credentials}
      export PGPASSWORD=${var.database_password}
      psql -h ${google_sql_database_instance.postgres.public_ip_address} -U ${google_sql_user.sensorthings_user.name} -d ${google_sql_database.sensorthings.name} -c "CREATE EXTENSION IF NOT EXISTS postgis;"
      psql -h ${google_sql_database_instance.postgres.public_ip_address} -U ${google_sql_user.sensorthings_user.name} -d ${google_sql_database.sensorthings.name} -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
      psql -h ${google_sql_database_instance.postgres.public_ip_address} -U ${google_sql_user.sensorthings_user.name} -d ${google_sql_database.sensorthings.name} -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;"
      psql -h ${google_sql_database_instance.postgres.public_ip_address} -U ${google_sql_user.sensorthings_user.name} -d ${google_sql_database.sensorthings.name} -c "CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;"
      psql -h ${google_sql_database_instance.postgres.public_ip_address} -U ${google_sql_user.sensorthings_user.name} -d ${google_sql_database.sensorthings.name} -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
    EOT
  }

  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_database.sensorthings,
    google_sql_user.sensorthings_user
  ]
}

# Artifact Registry Repository
resource "google_artifact_registry_repository" "wqp" {
  location      = var.region
  repository_id = "wqp-docker-repo"
  format        = "DOCKER"
}

resource "null_resource" "build_frost" {
  provisioner "local-exec" {
    command = <<-EOT
      docker buildx build \
        --platform linux/amd64 \
        --push \
        -t ${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server:latest \
        ./docker/frost
    EOT
  }

  depends_on = [google_artifact_registry_repository.wqp]
}

resource "null_resource" "build_dagster" {
  provisioner "local-exec" {
    command = <<-EOT
      docker buildx build \
        --platform linux/amd64 \
        --push \
        -t ${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/dagster:latest \
        .
    EOT
  }

  depends_on = [google_artifact_registry_repository.wqp]
}

# Cloud Run Service for FROST-Server
resource "google_cloud_run_v2_service" "frost_service" {
  name     = "wqp-frost-server"
  location = var.region
  ingress = "INGRESS_TRAFFIC_ALL"
  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server:latest"

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }

      resources {
        limits = {
          memory = "4Gi"
        }
      }
      
      env {
        name  = "serviceRootUrl"
        value = "https://${var.wqp_url}/FROST-Server"
      }

      env {
        name  = "persistence_db_url"
        value = "jdbc:postgresql://${google_sql_database_instance.postgres.public_ip_address}:5432/${google_sql_database.sensorthings.name}"
      }

      env {
        name  = "persistence_db_username"
        value = "${google_sql_user.sensorthings_user.name}"
      }

      env {
        name  = "persistence_db_password"
        value = "${var.database_password}"
      }

      env {
        name  = "logSensitiveData"
        value = "true"
      }

      env {
        name  = "FROST_LL"
        value = "DEBUG"
      }
    }
    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [google_sql_database_instance.postgres.connection_name]
      }
    }
  }
  deletion_protection=false
  client     = "terraform"
  depends_on = [null_resource.build_frost, null_resource.enable_postgis]
}

resource "google_cloud_run_service_iam_member" "frost_public" {
  location = google_cloud_run_v2_service.frost_service.location
  service  = google_cloud_run_v2_service.frost_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Run Job for Dagster
data "external" "generate_partitions" {
  program = ["uv", "run", "./src/wqp/partitions.py"]
}

resource "google_cloud_run_v2_job" "dagster_job" {
  name     = "wqp-dagster-job"
  location = var.region
  deletion_protection = false

  template {
    template {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/dagster:latest"

        resources {
          limits = {
            memory = "1Gi"
          }
        }

        env {
          name  = "SLACK_BOT_TOKEN"
          value = var.slack_bot_token
        }

        env {
          name  = "API_BACKEND_URL"
          value = "${google_cloud_run_v2_service.frost_service.uri}/FROST-Server/v1.1"
        }

      }
    }
  }

  depends_on = [null_resource.build_dagster, google_cloud_run_v2_service.frost_service]
}

resource "null_resource" "invoke_partition_jobs" {
  for_each = { for idx, partition in chunklist(keys(data.external.generate_partitions.result), 750) : idx => partition }

  provisioner "local-exec" {
    command = <<EOT
      gcloud run jobs execute wqp-dagster-job \
        --region=${var.region} \
        --args="${join(" ", each.value)}"
    EOT
  }

  depends_on = [google_cloud_run_v2_job.dagster_job]
}