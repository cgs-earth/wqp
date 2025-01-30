variable "project_id" {
  description = "The GCP project ID"
  type        = string
}

variable "region" {
  description = "The GCP region"
  type        = string
}

variable "frost_uri" {
  description = "The URI of the FROST server"
  type        = string
}

variable "slack_bot_token" {
  description = "Slack bot token for notifications"
  type        = string
  sensitive   = true
}

variable "partitions" {
  description = "A JSON string of partitions"
  type        = map(string)
}
