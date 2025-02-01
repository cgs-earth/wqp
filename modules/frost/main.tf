# Artifact Registry Repository
resource "null_resource" "build_frost" {
  provisioner "local-exec" {
    command = <<-EOT
      docker buildx build \
        --platform linux/amd64 \
        --push \
        -t ${var.region}-docker.pkg.dev/${var.project_id}/wqp-docker-repo/frost-server:latest \
        ./modules/frost
    EOT
  }
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
        value = "jdbc:postgresql:///${var.database_name}?socketFactory=com.google.cloud.sql.postgres.SocketFactory&cloudSqlInstance=${var.database_instance.connection_name}&unixSocketPath=/cloudsql/${var.database_instance.connection_name}/.s.PGSQL.5432"
      }

      env {
        name  = "persistence_db_username"
        value = var.database_user
      }

      env {
        name  = "persistence_db_password"
        value = var.database_password
      }

      env {
        name  = "persistence_countMode"
        value = "LIMIT_SAMPLE"
      }

      volume_mounts {
        name       = "cloudsql"
        mount_path = "/cloudsql"
      }
    }

    volumes {
      name = "cloudsql"
      cloud_sql_instance {
        instances = [var.database_instance.connection_name]
      }
    }

    scaling {
      min_instance_count = 1
      max_instance_count = 20
    }
  }

  deletion_protection = false
  depends_on = [null_resource.build_frost]
}

resource "google_cloud_run_service_iam_member" "public_access" {
  location = google_cloud_run_v2_service.frost_service.location
  service  = google_cloud_run_v2_service.frost_service.name
  role     = "roles/run.invoker"
  member   = "allUsers"
}


# PostgreSQL Index Job
resource "google_cloud_run_v2_job" "frost_indexes" {
  name     = "postgres-index-setup"
  location = var.region

  template {
    template {
      containers {
        image = "postgres:15"

        env {
          name  = "PGHOST"
          value = "/cloudsql/${var.database_instance.connection_name}"
        }
        env {
          name  = "PGDATABASE"
          value = var.database_name
        }
        env {
          name  = "PGUSER"
          value = var.database_user
        }
        env {
          name  = "PGPASSWORD"
          value = var.database_password
        }

        command = [
          "/bin/bash",
          "-c",
          <<-EOT
            psql -c 'CREATE INDEX IF NOT EXISTS idx_location_geom ON "LOCATIONS" USING gist ("GEOM");'
            psql -c 'CREATE INDEX IF NOT EXISTS idx_datastreams_obs_property_id_id ON "DATASTREAMS" USING btree ("OBS_PROPERTY_ID", "ID" asc);'
            psql -c 'CREATE INDEX IF NOT EXISTS idx_datastreams_things_id_id ON "DATASTREAMS" USING btree ("THING_ID", "ID" asc);'
            psql -c 'VACUUM FULL ANALYZE "DATASTREAMS";'
            psql -c 'VACUUM FULL ANALYZE "THINGS";'
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
          instances = [var.database_instance.connection_name]
        }
      }
    }
  }

  deletion_protection = false
}

resource "null_resource" "frost_indexes" {
  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute postgres-index-setup --region=${var.region}
    EOT
  }

  depends_on = [google_cloud_run_v2_job.frost_indexes]
}