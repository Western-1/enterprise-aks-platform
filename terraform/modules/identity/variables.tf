variable "name" {
  description = "Name of the user-assigned managed identity"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group of the identity"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "oidc_issuer_url" {
  description = "AKS OIDC issuer URL used for the federated credential"
  type        = string
}

variable "service_account_namespace" {
  description = "Namespace of the workload service account"
  type        = string
  default     = "media"
}

variable "service_account_name" {
  description = "Name of the workload service account"
  type        = string
  default     = "media-api"
}

variable "key_vault_id" {
  description = "Key Vault the identity can read secrets from"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}