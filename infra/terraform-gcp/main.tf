# BigQuery no modo sandbox: sem conta de cobranca, sem cartao e sem custo.
# Limite do sandbox: tabelas expiram em 60 dias, por isso a expiracao e declarada.
resource "google_bigquery_dataset" "pv" {
  dataset_id                  = var.dataset
  location                    = var.localizacao
  description                 = "Camadas gold da Plataforma Viva (agregados, sem dado pessoal)"
  default_table_expiration_ms = 5184000000
  delete_contents_on_destroy  = true
  labels                      = { projeto = "plataforma-viva", gerenciado_por = "terraform" }
}
