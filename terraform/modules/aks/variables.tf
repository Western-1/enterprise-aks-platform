variable "name" {
  type = string
}

variable "resource_group_name" {
  type = string
}

variable "location" {
  type = string
}

variable "kubernetes_version" {
  type    = string
  default = "1.34"
}

variable "node_resource_group" {
  description = "RG for cluster nodes. Leave null to auto-generate"
  type        = string
  default     = null
}

variable "sku_tier" {
  type    = string
  default = "Free"
}

variable "aks_subnet_id" {
  type = string
}

variable "system_pool_vm_size" {
  type    = string
  default = "Standard_EC2as_v5"
}

variable "system_pool_node_count" {
  type    = number
  default = 2
}

variable "system_pool_min_count" {
  type    = number
  default = null
}

variable "system_pool_max_count" {
  type    = number
  default = null
}

variable "user_pool_enabled" {
  type    = bool
  default = true
}

variable "user_pool_vm_size" {
  type    = string
  default = "Standard_EC2as_v5"
}

variable "user_pool_node_count" {
  type    = number
  default = 0
}

variable "user_pool_min_count" {
  type    = number
  default = 0
}

variable "user_pool_max_count" {
  type    = number
  default = 1
}

variable "user_pool_taints" {
  type    = list(string)
  default = []
}

variable "user_pool_labels" {
  type    = map(string)
  default = {}
}

variable "api_server_authorized_ip_ranges" {
  description = "CIDRs allowed to reach the Kubernetes API"
  type        = list(string)
  default     = []
}

variable "acr_id" {
  type    = string
  default = null
}

variable "log_analytics_workspace_id" {
  type    = string
  default = null
}

variable "tags" {
  type    = map(string)
  default = {}
}