output "job_name" {
  description = "The name of the Dagster Cloud Run job"
  value       = google_cloud_run_v2_job.dagster_job.name
}
