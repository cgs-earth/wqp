output "instance" {
  description = "The database instance resource"
  value       = google_sql_database_instance.postgres
}

output "instance_name" {
  description = "The name of the database instance"
  value       = google_sql_database_instance.postgres.name
}

output "database_name" {
  description = "The name of the database"
  value       = google_sql_database.sensorthings.name
}

output "user_name" {
  description = "The database user name"
  value       = google_sql_user.sensorthings_user.name
}

output "public_ip_address" {
  description = "The public IP address of the database instance"
  value       = google_sql_database_instance.postgres.public_ip_address
}
