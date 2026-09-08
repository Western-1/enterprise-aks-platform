output "identity_id" {
  value = azurerm_user_assigned_identity.uami.id
}

output "client_id" {
  value = azurerm_user_assigned_identity.uami.client_id
}

output "principal_id" {
  value = azurerm_user_assigned_identity.uami.principal_id
}