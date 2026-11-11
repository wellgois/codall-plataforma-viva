variable "regiao" {
  type        = string
  default     = "us-east-1"
  description = "Regiao dos recursos (us-east-1 costuma ser a mais barata para S3)."
}

variable "prefixo" {
  type        = string
  default     = "plataforma-viva"
  description = "Prefixo dos nomes; o bucket recebe tambem o id da conta."
}

variable "teto_mensal_usd" {
  type        = number
  default     = 8
  description = "Teto de gasto mensal em dolares (aprox. R$ 40-50). Alertas em 50%, 80% e 100%."
}

variable "email_alerta" {
  type        = string
  description = "E-mail que recebe os alertas de orcamento. Passe por TF_VAR_email_alerta ou .auto.tfvars (ignorado pelo git)."
}

variable "limite_athena_bytes" {
  type        = number
  default     = 104857600
  description = "Maximo de bytes lidos por consulta Athena (100 MB). Consulta que passar disso e cancelada."
}

variable "habilitar_athena" {
  type        = bool
  default     = true
  description = "Cria o workgroup Athena. Desligado so no teste simulado (o moto nao implementa tags do Athena)."
}

variable "habilitar_orcamento" {
  type        = bool
  default     = true
  description = "Cria o orcamento com alertas. Desligado so no teste simulado (o moto nao implementa assinaturas do Budgets)."
}
