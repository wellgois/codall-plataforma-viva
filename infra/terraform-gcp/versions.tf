terraform {
  required_version = ">= 1.6"
  required_providers {
    google = { source = "hashicorp/google", version = "~> 6.0" }
  }
}

# Credencial por GOOGLE_APPLICATION_CREDENTIALS (arquivo fora do repositorio).
provider "google" {
  project = var.project_id
}
