# ----------- Key Valult -----------
resource "azurerm_key_vault" "kv" {
  name                        = "kv-eshop-cloudx"
  location                    = azurerm_resource_group.rg-cloudx.location
  resource_group_name         = azurerm_resource_group.rg-cloudx.name
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

# ----------- Key Vault Access Policy -----------
# Get Public API managed identity principal id
data "azuread_service_principal" "sp-publicapi" {
  display_name = azurerm_windows_web_app.app-publicapi.name
  depends_on = [
    azurerm_windows_web_app.app-publicapi
  ]
}
resource "azurerm_key_vault_access_policy" "kvap-publicapi" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.sp-publicapi.object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "List"
  ]
}

# Get Web managed identity principal id
data "azuread_service_principal" "sp-web" {
  display_name = azurerm_windows_web_app.app-web.name
  depends_on = [
    azurerm_windows_web_app.app-web
  ]
}
resource "azurerm_key_vault_access_policy" "kvap-web" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.sp-web.object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "List"
  ]
}
