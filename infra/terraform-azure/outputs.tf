output "conta_armazenamento" { value = azurerm_storage_account.lake.name }
output "container" { value = azurerm_storage_container.lake.name }
output "identidade_publicador" { value = azurerm_user_assigned_identity.publicador.name }
