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