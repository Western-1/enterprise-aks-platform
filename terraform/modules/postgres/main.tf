resource "random_password" "db_admin" {
  length           = 24
  special          = true
  min_upper        = 1
  min_lower        = 1
  min_numeric      = 1
  min_special      = 1
  override_special = "!@#$%&*"
}

resource "azurerm_postgresql_flexible_server" "pg" {
  name                   = var.name
  resource_group_name    = var.resource_group_name
  location               = var.location
  version                = var.postgres_version
  administrator_login    = var.admin_username
  administrator_password = random_password.db_admin.result
  storage_mb             = var.storage_mb
  sku_name               = var.sku_name
  zone                   = "1"
  backup_retention_days  = var.backup_retention_days

  dynamic "high_availability" {
    for_each = var.enable_ha ? [1] : []
    content {
      mode = "ZoneRedundant"
    }
  }

  tags = var.tags
}

resource "azurerm_private_endpoint" "pe" {
  name                = "pe-${var.name}"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.private_endpoint_subnet_id

  private_service_connection {
    name                           = "psc-${var.name}"
    private_connection_resource_id = azurerm_postgresql_flexible_server.pg.id
    is_manual_connection           = false
    subresource_names              = ["postgresqlServer"]
  }

  private_dns_zone_group {
    name                 = "dns-${var.name}"
    private_dns_zone_ids = [var.private_dns_zone_id]
  }
}

resource "azurerm_key_vault_secret" "db_password" {
  name         = "db-password"
  value        = random_password.db_admin.result
  key_vault_id = var.key_vault_id
}

resource "azurerm_key_vault_secret" "db_url" {
  name         = "db-url"
  value        = "postgresql://${var.admin_username}@${azurerm_postgresql_flexible_server.pg.name}:${random_password.db_admin.result}@${azurerm_postgresql_flexible_server.pg.name}.postgres.database.azure.com:5432/${var.database_name}"
  key_vault_id = var.key_vault_id
}