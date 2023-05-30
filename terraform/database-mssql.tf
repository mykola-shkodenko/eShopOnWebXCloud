# ----------- Database MS SQL -----------
resource "azurerm_mssql_server" "sql-server" {
  name                         = "sql-eshop-cloudx"
  resource_group_name          = azurerm_resource_group.this.name
  location                     = azurerm_resource_group.this.location
  version                      = "12.0"
  administrator_login          = var.sql_admin
  administrator_login_password = var.sql_admin_pass
  minimum_tls_version          = "1.2"
}

resource "azurerm_mssql_database" "sql-db" {
  name           = "sqldb-eShopOnWeb"
  server_id      = azurerm_mssql_server.sql-server.id
  collation      = "SQL_Latin1_General_CP1_CI_AS"
  license_type   = "LicenseIncluded"
  max_size_gb    = 2
  sku_name       = "S0"
  zone_redundant = false
}

# Create SQL Server firewall rule for Azure resouces access
resource "azurerm_mssql_firewall_rule" "sql-rule-azure" {
  name             = "allow-azure-services"
  server_id        = azurerm_mssql_server.sql-server.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}