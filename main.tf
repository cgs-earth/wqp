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
    tier = "db-f1-micro"
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
resource "google_cloud_run_service" "frost_service" {
  name     = "wqp-frost-server"
  location = var.region

  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server:latest"

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
          value = "jdbc:postgresql:///sensorthings?socketFactory=com.google.cloud.sql.postgres.SocketFactory&unixSocketPath=/cloudsql/${google_sql_database_instance.postgres.connection_name}&cloudSqlInstance=${google_sql_database_instance.postgres.connection_name}"
        }

        env {
          name  = "persistence_db_username"
          value = "${google_sql_user.sensorthings_user.name}"
        }

        env {
          name  = "persistence_db_password"
          value = "${var.database_password}"
        }
      }
    }
    metadata {
      annotations = {
        "autoscaling.knative.dev/minScale"      = "1"
        "autoscaling.knative.dev/maxScale"      = "10"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
        "run.googleapis.com/client-name"        = "frost"
      }
    }
  }

  depends_on = [null_resource.build_frost]
}

resource "google_cloud_run_service_iam_member" "frost_public" {
  location = google_cloud_run_service.frost_service.location
  service  = google_cloud_run_service.frost_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}

# Cloud Run Service for Dagster
resource "google_cloud_run_service" "dagster_service" {
  name     = "wqp-dagster"
  location = var.region


  template {
    spec {
      containers {
        image = "${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/dagster:latest"

        ports {
          container_port = 3000
        }

        resources {
          limits = {
            memory = "2Gi"
          }
        }
        
        env {
          name  = "SLACK_BOT_TOKEN"
          value = var.slack_bot_token
        }

        env {
          name  = "API_BACKEND_URL"
          value = "${google_cloud_run_service.frost_service.status[0].url}/FROST-Server/v1.1"
        }

        env {
          name  = "SLACK_BOT_TOKEN"
          value = var.slack_bot_token
        }
      }
    }

    metadata {
      annotations = {
        "autoscaling.knative.dev/maxScale"      = "2"
        "run.googleapis.com/cloudsql-instances" = google_sql_database_instance.postgres.connection_name
        "run.googleapis.com/client-name"        = "dagster"
      }
    }
  }

  depends_on = [null_resource.build_dagster]
}

resource "google_cloud_run_service_iam_member" "dagster_public" {
  location = google_cloud_run_service.dagster_service.location
  service  = google_cloud_run_service.dagster_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}