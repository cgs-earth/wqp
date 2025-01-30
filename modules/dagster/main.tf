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
          value = "${var.frost_uri}/FROST-Server/v1.1"
        }
      }
    }
  }

  depends_on = [null_resource.build_dagster]
}

resource "null_resource" "invoke_partition_jobs" {
  for_each = { for idx, partition in chunklist(keys(var.partitions), 500) : idx => partition }

  provisioner "local-exec" {
    command = <<-EOT
      gcloud run jobs execute wqp-dagster-job \
        --region=${var.region} \
        --args="${join(" ", each.value)}"
    EOT
  }

  depends_on = [google_cloud_run_v2_job.dagster_job]
}
