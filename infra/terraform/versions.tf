terraform {
  required_version = ">= 1.6"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 5.0" }
  }
}

provider "aws" {
  region = var.regiao
  default_tags {
    tags = { projeto = "plataforma-viva", gerenciado_por = "terraform" }
  }
}
