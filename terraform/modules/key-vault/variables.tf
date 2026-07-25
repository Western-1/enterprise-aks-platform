variable "name" {
  description = "Key Vault name"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "tenant_id" {
  type = string
}

variable "current_user_object_id" {
  description = "Object ID of the current user (granted Key Vault Administrator)"
  type        = string
}

variable "sku" {
  type    = string
  default = "standard"
}

variable "allow_public" {
  description = "When false, the vault is reachable only via private endpoint"
  type        = bool
  default     = false
}

variable "allowed_ip_ranges" {
  description = "Public IPs allowed through the firewall (for terraform/dev machine)"
  type        = list(string)
  default     = []
}

variable "private_endpoint_subnet_id" {
  type    = string
  default = null
}

variable "private_dns_zone_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}