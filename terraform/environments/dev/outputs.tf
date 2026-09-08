output "resource_group_name" {
  value = azurerm_resource_group.rg.name
}

output "vnet_id" {
  value = module.networking.vnet_id
}

output "vnet_name" {
  value = module.networking.vnet_name
}

output "subnet_ids" {
  value = module.networking.subnet_ids
}

output "media_identity_client_id" {
  value = module.identity.client_id
}

output "media_identity_principal_id" {
  value = module.identity.principal_id
}