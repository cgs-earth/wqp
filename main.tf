# Provider configuration
provider "google" {
  project = var.project_id
  region  = var.region
  credentials = file(var.credentials)
}

# VPC Network
resource "google_compute_network" "default" {
  name                    = "wqp-serverless-network"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "wqp_subnet" {
  name          = "wqp-serverless-subnet"
  ip_cidr_range = "10.0.0.0/24"
  region        = var.region
  network       = google_compute_network.default.id

  private_ip_google_access = true
}

# Serverless VPC Access Connector
resource "google_vpc_access_connector" "connector" {
  name          = "wqp-serverless-connector"
  region        = var.region
  network       = google_compute_network.default.name
  ip_cidr_range = "10.8.0.0/28"
  min_instances = 2
  max_instances = 4
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com",
    "vpcaccess.googleapis.com",
    "servicenetworking.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

# Private IP for Cloud SQL
resource "google_compute_global_address" "private_ip_address" {
  name          = "wqp-private-ip"
  purpose       = "VPC_PEERING"
  address_type  = "INTERNAL"
  prefix_length = 16
  network       = google_compute_network.default.id
}

resource "google_service_networking_connection" "private_vpc_connection" {
  network                 = google_compute_network.default.id
  service                 = "servicenetworking.googleapis.com"
  reserved_peering_ranges = [google_compute_global_address.private_ip_address.name]
}

# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "wqp-postgres-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier = "db-g1-small"
    disk_autoresize = true
    ip_configuration {
      ipv4_enabled    = false
      private_network = google_compute_network.default.id
    }
  }

  deletion_protection = true

  depends_on = [google_service_networking_connection.private_vpc_connection]
}

# Database for Sensorthings
resource "google_sql_database" "sensorthings" {
  name     = "sensorthings"
  instance = google_sql_database_instance.postgres.name
}

# Database User (consider using Secret Manager for password)
resource "google_sql_user" "sensorthings_user" {
  name     = "sensorthings"
  instance = google_sql_database_instance.postgres.name
  password = var.database_password
}

# PostGIS Extension Provisioning (Now using Cloud SQL proxy)
resource "google_cloud_run_v2_job" "postgis_setup" {
  name     = "postgis-extension-setup"
  location = var.region

  template {
    template {
      containers {
        image = "postgres:15"  # Use official PostgreSQL image

        # Environment variables for connection
        env {
          name  = "PGHOST"
          value = google_sql_database_instance.postgres.private_ip_address
        }
        env {
          name  = "PGDATABASE"
          value = google_sql_database.sensorthings.name
        }
        env {
          name  = "PGUSER"
          value = google_sql_user.sensorthings_user.name
        }
        env {
          name  = "PGPASSWORD"
          value = var.database_password
        }

        # Command to create extensions
        command = [
          "/bin/bash",
          "-c",
          <<-EOT
            psql -c "CREATE EXTENSION IF NOT EXISTS postgis;"
            psql -c "CREATE EXTENSION IF NOT EXISTS postgis_topology;"
            psql -c "CREATE EXTENSION IF NOT EXISTS fuzzystrmatch;"
            psql -c "CREATE EXTENSION IF NOT EXISTS postgis_tiger_geocoder;"
            psql -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
          EOT
        ]
      }

      # VPC Access 
      vpc_access {
        connector = google_vpc_access_connector.connector.id
        egress    = "ALL_TRAFFIC"
      }
    }
  }

  # Disable deletion protection
  deletion_protection = false

  depends_on = [
    google_sql_database_instance.postgres,
    google_sql_database.sensorthings,
    google_sql_user.sensorthings_user,
    google_vpc_access_connector.connector
  ]
}

resource "null_resource" "enable_postgis" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute postgis-extension-setup --region=${var.region}
    EOT
  }

  depends_on = [google_cloud_run_v2_job.postgis_setup]
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
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
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
        value = "jdbc:postgresql://${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.sensorthings.name}"
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

    scaling {
      min_instance_count = 1
      max_instance_count = 20
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "ALL_TRAFFIC"
    }

  }

  deletion_protection = false
  client              = "terraform"
  
  depends_on = [
    null_resource.build_frost, 
    null_resource.enable_postgis,
    google_vpc_access_connector.connector
  ]
}

resource "google_cloud_run_service_iam_member" "public_access" {
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
      timeout = "86400s"

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

  depends_on = [
    null_resource.build_dagster, 
    google_cloud_run_v2_service.frost_service
  ]
}

resource "null_resource" "invoke_partition_jobs" {
  for_each = { for idx, partition in chunklist(keys(data.external.generate_partitions.result), 500) : idx => partition }

  provisioner "local-exec" {
    command = <<EOT
      gcloud run jobs execute wqp-dagster-job \
        --region=${var.region} \
        --args="${join(" ", each.value)}"
    EOT
  }

  depends_on = [google_cloud_run_v2_job.dagster_job]
}

##############################################################
# FROST Dev server


resource "google_storage_bucket" "logs" {
  name     = "${var.project_id}-frost-logs"
  location = var.region
  uniform_bucket_level_access = true
}

# Log sink to route logs to storage
resource "google_logging_project_sink" "frost_logs" {
  name        = "frost-logs-sink"
  destination = "storage.googleapis.com/${google_storage_bucket.logs.name}"
  filter      = "resource.type=cloud_run_revision AND resource.labels.service_name=${google_cloud_run_v2_service.frost_service_dev.name}"

  unique_writer_identity = true
}

# IAM binding for log writer
resource "google_project_iam_binding" "log_writer" {
  project = var.project_id
  role    = "roles/storage.objectCreator"
  members = [google_logging_project_sink.frost_logs.writer_identity]
}

resource "null_resource" "build_frost_dev" {
  provisioner "local-exec" {
    command = <<-EOT
      docker buildx build \
        --platform linux/amd64 \
        --push \
        -t ${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server:dev \
        ./docker/frost
    EOT
  }

  depends_on = [google_artifact_registry_repository.wqp]
}

# Cloud Run Service for FROST-Server
resource "google_cloud_run_v2_service" "frost_service_dev" {
  name     = "wqp-frost-server-dev"
  location = var.region
  ingress  = "INGRESS_TRAFFIC_ALL"

  template {
    containers {
      image = "${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server-test:dev"

      resources {
        limits = {
          memory = "4Gi"
        }
      }
      
      env {
        name  = "http_requestDecoder_autodetectRootUrl"
        value = "true"
      }

      env {
        name  = "persistence_db_url"
        value = "jdbc:postgresql://${google_sql_database_instance.postgres.private_ip_address}:5432/${google_sql_database.sensorthings.name}"
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

    scaling {
      min_instance_count = 1
      max_instance_count = 20
    }

    vpc_access {
      connector = google_vpc_access_connector.connector.id
      egress    = "ALL_TRAFFIC"
    }

  }

  deletion_protection = false
  client              = "terraform"
  
  depends_on = [
    null_resource.build_frost_dev, 
    null_resource.enable_postgis,
    google_vpc_access_connector.connector
  ]
}

resource "google_cloud_run_service_iam_member" "public_access_dev" {
  location = google_cloud_run_v2_service.frost_service_dev.location
  service  = google_cloud_run_v2_service.frost_service_dev.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}