terraform {
  required_version = ">= 1.8"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
}

locals {
  environment = "dev"
  region      = "ne"
  name_prefix = "dev"
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}-aks-${local.region}"
  location = "northeurope"
}

module "networking" {
  source = "../../modules/networking"

  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  vnet_name           = "vnet-${local.name_prefix}-aks-${local.region}"
  vnet_address_space  = ["10.0.0.0/16"]

  subnets = {
    aks = {
      address_prefixes = ["10.0.1.0/24"]
    }
    app = {
      address_prefixes = ["10.0.2.0/24"]
    }
    private-endpoint = {
      address_prefixes = ["10.0.3.0/24"]
    }
  }
}

module "acr" {
  source = "../../modules/acr"

  name                = "acrdevmedia"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku                 = "Basic"
}

module "key_vault" {
  source = "../../modules/key-vault"

  name                       = "kv-dev-media-ne"
  resource_group_name        = azurerm_resource_group.rg.name
  location                   = azurerm_resource_group.rg.location
  tenant_id                  = "e6b52a20-0ba0-4ffd-951d-183b04425ed2"
  current_user_object_id     = "6489c989-ee54-4e99-a2ad-f60a1acd493d"
  allow_public               = false
  private_endpoint_subnet_id = module.networking.subnet_ids["private-endpoint"]
  private_dns_zone_id        = module.networking.private_dns_zone_ids["keyvault"]
}

module "monitoring" {
  source = "../../modules/monitoring"

  name                = "la-dev-aks-ne"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
}

module "aks" {
  source = "../../modules/aks"

  name                            = "aks-dev-cluster-ne"
  resource_group_name             = azurerm_resource_group.rg.name
  location                        = azurerm_resource_group.rg.location
  aks_subnet_id                   = module.networking.subnet_ids["aks"]
  api_server_authorized_ip_ranges = ["31.134.118.200/32"]
  acr_id                          = module.acr.acr_id
  log_analytics_workspace_id      = module.monitoring.workspace_id
}