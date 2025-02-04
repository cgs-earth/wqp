# Provider configuration
provider "google" {
  region              = var.region
  credentials         = file(var.credentials)
}

locals {
  credentials = jsondecode(file(var.credentials))
}

# Enable required APIs
resource "google_project_service" "apis" {
  for_each = toset([
    "sqladmin.googleapis.com",
    "run.googleapis.com",
    "cloudbuild.googleapis.com",
    "secretmanager.googleapis.com"
  ])
  service            = each.key
  disable_on_destroy = false
}

resource "google_artifact_registry_repository" "wqp" {
  location           = var.region
  repository_id      = "wqp-docker-repo"
  format             = "DOCKER"
}

data "external" "generate_partitions" {
  program = ["uv", "run", "./src/wqp/partitions.py"]
}

module "database" {
  source = "./modules/database"
  
  project_id         = local.credentials.project_id
  region             = var.region
  database_password  = var.database_password
  
  depends_on = [google_project_service.apis]
}

module "frost" {
  source = "./modules/frost"
  
  project_id         = local.credentials.project_id
  region             = var.region
  wqp_url            = var.wqp_url
  service_account    = local.credentials.client_email
  database_instance  = module.database.instance
  database_name      = module.database.database_name
  database_user      = module.database.user_name
  database_password  = var.database_password
  
  depends_on = [module.database, google_artifact_registry_repository.wqp]
}

module "dagster" {
  source = "./modules/dagster"
  
  project_id         = local.credentials.project_id
  region             = var.region
  frost_uri          = module.frost.service_uri
  slack_bot_token    = var.slack_bot_token
  partitions         = data.external.generate_partitions.result
  
  depends_on = [module.frost, google_artifact_registry_repository.wqp]
}
