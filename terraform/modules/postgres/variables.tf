variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "admin_username" {
  type    = string
  default = "mediaadmin"
}

variable "database_name" {
  type    = string
  default = "media"
}

variable "postgres_version" {
  type    = string
  default = "16"
}

variable "sku_name" {
  type    = string
  default = "B_Standard_B1ms"
}

variable "storage_mb" {
  type    = number
  default = 32768
}

variable "backup_retention_days" {
  type    = number
  default = 7
}

variable "enable_ha" {
  description = "Zone-redundant HA (not supported on burstable tiers)"
  type        = bool
  default     = false
}

variable "private_endpoint_subnet_id" {
  type = string
}

variable "private_dns_zone_id" {
  type = string
}

variable "key_vault_id" {
  type = string
}

variable "tags" {
  type    = map(string)
  default = {}
}