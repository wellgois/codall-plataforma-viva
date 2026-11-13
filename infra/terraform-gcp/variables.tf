variable "project_id" {
  type        = string
  description = "Id do projeto GCP. Passe por TF_VAR_project_id (nao versionar)."
}

variable "localizacao" {
  type        = string
  default     = "US"
  description = "Localizacao do dataset do BigQuery."
}

variable "dataset" {
  type        = string
  default     = "plataforma_viva"
  description = "Nome do dataset que recebe as tabelas gold."
}
