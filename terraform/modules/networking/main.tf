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

resource "azurerm_network_security_rule" "lb_ingress" {
  for_each = { for idx, port in var.lb_ingress_ports : port => idx }

  name                        = "AllowLbInbound-${each.key}"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg["aks"].name
  priority                    = 1000 + each.value * 10
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = tostring(each.key)
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
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