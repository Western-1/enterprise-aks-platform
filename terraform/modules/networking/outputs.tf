output "vnet_id" {
  value = azurerm_virtual_network.vnet.id
}

output "vnet_name" {
  value = azurerm_virtual_network.vnet.name
}

output "subnet_ids" {
  value = {
    for name, subnet in azurerm_subnet.subnet : name => subnet.id
  }
}

output "private_dns_zone_ids" {
  value = {
    for name, zone in azurerm_private_dns_zone.privatelink : name => zone.id
  }
}