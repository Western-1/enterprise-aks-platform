variable "name" {
  description = "Globally unique ACR name (no dashes allowed)"
  type        = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "sku" {
  description = "SKU: Basic, Standard, Premium"
  type        = string
  default     = "Basic"
}

variable "tags" {
  type    = map(string)
  default = {}
}