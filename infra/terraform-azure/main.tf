resource "random_string" "sufixo" {
  length  = 6
  upper   = false
  special = false
}

locals {
  conta = "${var.prefixo}${random_string.sufixo.result}"
}

resource "azurerm_resource_group" "pv" {
  name     = "${var.prefixo}-rg"
  location = var.regiao
  tags     = { projeto = "plataforma-viva", gerenciado_por = "terraform" }
}

# Armazenamento: unico recurso com custo proporcional ao uso (equivalente ao S3 da Fase 5)
resource "azurerm_storage_account" "lake" {
  name                            = local.conta
  resource_group_name             = azurerm_resource_group.pv.name
  location                        = azurerm_resource_group.pv.location
  account_tier                    = "Standard"
  account_replication_type        = "LRS"
  account_kind                    = "StorageV2"
  is_hns_enabled                  = true # Data Lake Gen2
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  tags                            = azurerm_resource_group.pv.tags
}

resource "azurerm_storage_container" "lake" {
  name                  = "lake"
  storage_account_id    = azurerm_storage_account.lake.id
  container_access_type = "private"
}

resource "azurerm_storage_management_policy" "limpeza" {
  storage_account_id = azurerm_storage_account.lake.id
  rule {
    name    = "resultados-7-dias"
    enabled = true
    filters {
      prefix_match = ["lake/consultas/"]
      blob_types   = ["blockBlob"]
    }
    actions {
      base_blob { delete_after_days_since_modification_greater_than = 7 }
    }
  }
}

# Acesso minimo: o publicador so escreve no conteudo da conta (papel de dados de blob), nunca gerencia a assinatura
resource "azurerm_user_assigned_identity" "publicador" {
  name                = "${var.prefixo}-publicador"
  resource_group_name = azurerm_resource_group.pv.name
  location            = azurerm_resource_group.pv.location
}

resource "azurerm_role_assignment" "publicador" {
  scope                = azurerm_storage_account.lake.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_user_assigned_identity.publicador.principal_id
}

# Teto de gasto: alerta (nao bloqueia)
resource "azurerm_consumption_budget_resource_group" "teto" {
  name              = "${var.prefixo}-teto"
  resource_group_id = azurerm_resource_group.pv.id
  amount            = var.teto_mensal_usd
  time_grain        = "Monthly"
  time_period {
    start_date = var.inicio_orcamento
  }
  dynamic "notification" {
    for_each = [50, 80, 100]
    content {
      enabled        = true
      threshold      = notification.value
      operator       = "GreaterThan"
      threshold_type = "Actual"
      contact_emails = [var.email_alerta]
    }
  }
}
