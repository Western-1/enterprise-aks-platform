resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  resource_group_name = var.resource_group_name
  location            = var.location
  address_space       = var.vnet_address_space

  tags = var.tags
}

resource "azurerm_subnet" "subnet" {
  for_each             = var.subnets
  name                 = "snet-${each.key}"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = each.value.address_prefixes
}

resource "azurerm_network_security_group" "nsg" {
  for_each            = var.subnets
  name                = "nsg-${each.key}"
  resource_group_name = var.resource_group_name
  location            = var.location

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each                  = var.subnets
  subnet_id                 = azurerm_subnet.subnet[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

resource "azurerm_private_dns_zone" "privatelink" {
  for_each            = var.private_dns_zones
  name                = each.value
  resource_group_name = var.resource_group_name
}

resource "azurerm_private_dns_zone_virtual_network_link" "privatelink_link" {
  for_each              = var.private_dns_zones
  name                  = "${replace(each.value, ".", "-")}-link"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.privatelink[each.key].name
  virtual_network_id    = azurerm_virtual_network.vnet.id
}
