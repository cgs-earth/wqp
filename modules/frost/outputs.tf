output "service_url" {
  description = "The URL of the FROST server"
  value       = google_cloud_run_v2_service.frost_service.uri
}

output "service_uri" {
  description = "The URI of the FROST server"
  value       = google_cloud_run_v2_service.frost_service.uri
}
