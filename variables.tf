variable "region" {
  description = "The GCP region"
  type        = string
}

variable "credentials" {
  description = "Path to the GCP credentials file"
  type        = string
}

variable "database_password" {
  description = "Password for the database user"
  type        = string
  sensitive   = true
}

variable "wqp_url" {
  description = "URL for the WQP application"
  type        = string
}

variable "slack_bot_token" {
  description = "Slack bot token for notifications"
  type        = string
  sensitive   = true
}
