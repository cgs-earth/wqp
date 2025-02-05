variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "wqp_url" {
  description = "URL for the WQP application"
  type        = string
}

variable "database_instance" {
  description = "The database instance resource"
  type        = any
}

variable "database_name" {
  description = "The name of the database"
  type        = string
}

variable "database_user" {
  description = "The database user name"
  type        = string
}

variable "database_password" {
  description = "The database password"
  type        = string
  sensitive   = true
}

variable "service_account" {
  description = "Service account email"
  type        = string
}
