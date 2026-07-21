variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space of the virtual network"
  type        = list(string)
}

variable "subnets" {
  description = "Map of subnets: name -> { address_prefixes }"
  type = map(object({
    address_prefixes = list(string)
  }))
}

variable "private_dns_zones" {
  description = "Private DNS zones to create (privatelink.*)"
  type        = map(string)
  default = {
    postgres = "privatelink.postgres.database.azure.com"
    keyvault = "privatelink.vaultcore.azure.net"
    blob     = "privatelink.blob.core.windows.net"
  }
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}
