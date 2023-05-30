# ----------- Key Valult -----------
resource "azurerm_key_vault" "kv" {
  name                        = "kv-eshop-cloudx"
  location                    = azurerm_resource_group.this.location
  resource_group_name         = azurerm_resource_group.this.name
  enabled_for_disk_encryption = true
  tenant_id                   = data.azurerm_client_config.current.tenant_id
  soft_delete_retention_days  = 7
  purge_protection_enabled    = false

  sku_name = "standard"

  access_policy {
    tenant_id = data.azurerm_client_config.current.tenant_id
    object_id = data.azurerm_client_config.current.object_id

    key_permissions = [
      "Create",
      "Get",
    ]

    secret_permissions = [
      "Set",
      "Get",
      "Delete",
      "Purge",
      "Recover"
    ]

    storage_permissions = [
      "Get",
    ]
  }
}

resource "azurerm_key_vault_secret" "kvs-db-connection" {
  name         = "db-connection-string"
  value        = "Server=tcp:${azurerm_mssql_server.sql-server.name}.database.windows.net,1433;Initial Catalog=${azurerm_mssql_database.sql-db.name};Persist Security Info=False;User ID=${var.sql_admin};Password=${var.sql_admin_pass};MultipleActiveResultSets=True;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
  key_vault_id = azurerm_key_vault.kv.id
}
