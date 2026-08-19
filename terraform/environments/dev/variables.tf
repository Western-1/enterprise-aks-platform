variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  sensitive   = true
}

variable "tenant_id" {
  description = "Entra ID tenant ID"
  type        = string
  sensitive   = true
}

variable "current_user_object_id" {
  description = "Object ID of the user who gets Key Vault Administrator"
  type        = string
  sensitive   = true
}

variable "home_ip" {
  description = "Public IP of the dev machine (Key Vault firewall + AKS API allowlist)"
  type        = string
  sensitive   = true
}