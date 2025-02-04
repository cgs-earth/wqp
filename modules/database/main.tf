# Cloud SQL PostgreSQL Instance
resource "google_sql_database_instance" "postgres" {
  name             = "wqp-postgres-instance"
  database_version = "POSTGRES_15"
  region           = var.region

  settings {
    tier            = "db-custom-1-3840"
    disk_autoresize = true

    ip_configuration {
      ipv4_enabled = true
    }

    database_flags {
      name  = "cloudsql.enable_pg_cron"
      value = "on"
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

# PostGIS Extension Setup Job
resource "google_cloud_run_v2_job" "postgis_setup" {
  name     = "postgis-extension-setup"
  location = var.region
  template {
    template {
      containers {
        image = "postgres:15"

        env {
          name  = "PGHOST"
          value = "/cloudsql/${google_sql_database_instance.postgres.connection_name}"
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

        volume_mounts {
          name = "cloudsql"
          mount_path = "/cloudsql"
        }
      }

      volumes {
        name = "cloudsql"
        cloud_sql_instance {
          instances = [google_sql_database_instance.postgres.connection_name]
        }
      }
    }
  }

  deletion_protection = false
}

resource "null_resource" "enable_postgis" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute postgis-extension-setup --region=${var.region}
    EOT
  }

  depends_on = [google_cloud_run_v2_job.postgis_setup]
}