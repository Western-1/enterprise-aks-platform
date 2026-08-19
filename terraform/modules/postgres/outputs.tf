output "postgres_id" {
  value = azurerm_postgresql_flexible_server.pg.id
}

output "postgres_name" {
  value = azurerm_postgresql_flexible_server.pg.name
}

output "postgres_fqdn" {
  value = azurerm_postgresql_flexible_server.pg.fqdn
}

output "postgres_admin_username" {
  value = azurerm_postgresql_flexible_server.pg.administrator_login
}