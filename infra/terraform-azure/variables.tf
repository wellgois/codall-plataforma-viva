variable "subscription_id" {
  type        = string
  description = "Id da assinatura Azure. Passe por TF_VAR_subscription_id (nao versionar)."
}

variable "regiao" {
  type        = string
  default     = "brazilsouth"
  description = "Regiao dos recursos."
}

variable "prefixo" {
  type        = string
  default     = "pviva"
  description = "Prefixo dos nomes (so minusculas e numeros, ate 11 caracteres; a conta de armazenamento recebe um sufixo)."
}

variable "teto_mensal_usd" {
  type        = number
  default     = 8
  description = "Teto de gasto mensal em dolares. Alertas em 50%, 80% e 100%."
}

variable "email_alerta" {
  type        = string
  description = "E-mail que recebe os alertas de orcamento. Passe por TF_VAR_email_alerta."
}

variable "inicio_orcamento" {
  type        = string
  default     = "2027-01-01T00:00:00Z"
  description = "Primeiro dia de um mes (exigencia da Azure) a partir do qual o orcamento vale."
}
