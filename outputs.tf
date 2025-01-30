
output "repository_name" {
  description = "The name of the Artifact Registry repository"
  value       = google_artifact_registry_repository.wqp.name
}

output "frost_service_url" {
  description = "The URL of the FROST server"
  value       = module.frost.service_url
}

output "database_instance" {
  description = "The database instance name"
  value       = module.database.instance_name
}
