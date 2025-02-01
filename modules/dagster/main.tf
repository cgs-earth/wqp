# main.tf
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
}

resource "google_cloud_run_v2_job" "dagster_job" {
  name     = "wqp-dagster-job"
  location = var.region
  deletion_protection = false
  launch_stage = "BETA"

  template {
    task_count  = length(keys(var.partitions))
    parallelism = 10

    template {
      timeout     = "172800s"
      max_retries = 1

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
          value = "${var.frost_uri}/FROST-Server/v1.1"
        }
      }
    }
  }

  depends_on = [null_resource.build_dagster]
}

resource "null_resource" "post_sensor" {
  provisioner "local-exec" {
    command = <<EOT
      curl -X POST "http://localhost:8888/FROST-Server/v1.1/Sensors" \
           -H "Content-Type: application/json" \
           -d '{
                "@iot.id": 1,
                "name": "Unknown",
                "description": "Unknown",
                "encodingType": "Unknown",
                "metadata": "Unknown"
           }'
    EOT
  }

  depends_on = [google_cloud_run_v2_job.dagster_job]
}

resource "null_resource" "invoke_partition_jobs" {

  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute wqp-dagster-job \
        --region=${var.region}
    EOT
  }

  depends_on = [null_resource.post_sensor]
}
