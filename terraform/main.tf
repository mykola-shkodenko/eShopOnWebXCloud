terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "=3.54.0"
    }
  }
}

# Configure the Microsoft Azure Provider
provider "azurerm" {
  features {
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

variable "app_web_name" {
  type    = string
  default = "app-web-eshop-cloudx"
}
variable "app_publicapi_name" {
  type    = string
  default = "app-publicapi-eshop-cloudx"
}
variable "func_app_name" {
  type    = string
  default = "func-app-eshop-cloudx"
}
variable "sql_server_name" {
  type    = string
  default = "xcloud-admin"
}
variable "sql_db_name" {
  type    = string
  default = "sqldb-eShopOnWeb"
}
variable "sql_admin" {
  type    = string
  default = "xcloud-admin"
}
variable "sql_admin_pass" {
  type    = string
  default = "@someThingComplicated1234"
}

data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "rg-cloudx" {
  name     = "rg-key-vault-eus"
  location = "East US"
  tags = {
    module = "Key Vault"
  }
}

# Create application service plan
resource "azurerm_service_plan" "asp-web" {
  name                = "asp-eshop-cloudx"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_resource_group.rg-cloudx.location
  sku_name            = "F1"
  os_type             = "Windows"
}

# Create storage account
resource "azurerm_storage_account" "st-acc" {
  name                     = "steshopcloudx"
  resource_group_name      = azurerm_resource_group.rg-cloudx.name
  location                 = azurerm_resource_group.rg-cloudx.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# ----------- Database MS SQL -----------
resource "azurerm_mssql_server" "sql-server" {
  name                         = "sql-eshop-cloudx"
  resource_group_name          = azurerm_resource_group.rg-cloudx.name
  location                     = azurerm_resource_group.rg-cloudx.location
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
  name                = "allow-azure-services"
  server_id         = azurerm_mssql_server.sql-server.id
  start_ip_address    = "0.0.0.0"
  end_ip_address      = "0.0.0.0"
}

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

# ----------- Func App -----------
# Create application insights for func app
resource "azurerm_application_insights" "appi-funcapp" {
  name                = "appi-funcapp-eshop-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  application_type    = "web"
}

# Create consumption app service plan
resource "azurerm_service_plan" "aps-funcapp" {
  name                = "aps-funcapp-eshop-cloudx"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_resource_group.rg-cloudx.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

# Create func app 
resource "azurerm_windows_function_app" "func-app" {
  name                       = var.func_app_name
  resource_group_name        = azurerm_resource_group.rg-cloudx.name
  location                   = azurerm_resource_group.rg-cloudx.location
  storage_account_name       = azurerm_storage_account.st-acc.name
  storage_account_access_key = azurerm_storage_account.st-acc.primary_access_key
  service_plan_id            = azurerm_service_plan.aps-funcapp.id

  site_config {
    always_on = false
    application_stack {
      dotnet_version              = "v7.0"
      use_dotnet_isolated_runtime = true
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY        = azurerm_application_insights.appi-funcapp.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING = azurerm_application_insights.appi-funcapp.connection_string
    WEBSITE_RUN_FROM_PACKAGE              = 1
    ORDERS_CONTAINER_URL                  = ""
    COSMOS_ENDPOINT                       = ""
    COSMOS_DATABASE                       = "eShopOnWebDb"
    COSMOS_ORDERS_CONTAINER               = "orders"
  }
}

# ----------- Public API -----------
# Create application insights for PublicAPI
resource "azurerm_application_insights" "appi-publicapi" {
  name                = "appi-public-eshop-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  application_type    = "web"
}

# Create web app for Public API
resource "azurerm_windows_web_app" "app-publicapi" {
  name                = var.app_publicapi_name
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  service_plan_id     = azurerm_service_plan.asp-web.id

  site_config {
    always_on = false
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v7.0"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.appi-publicapi.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.appi-publicapi.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
  }

  connection_string {
    name  = "CatalogConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
  }
}

# ----------- Web -----------
# Create application insights for Web
resource "azurerm_application_insights" "appi-web" {
  name                = "appi-web-eshop-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  application_type    = "web"
}

# Create web app for Web
resource "azurerm_windows_web_app" "app-web" {
  name                = var.app_web_name
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  service_plan_id     = azurerm_service_plan.asp-web.id

  site_config {
    always_on = false
    application_stack {
      current_stack  = "dotnet"
      dotnet_version = "v7.0"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.appi-web.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.appi-web.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
    "baseUrls:apiBase"                         = "https://${var.app_publicapi_name}.azurewebsites.net/api/"
    "baseUrls:webBase"                         = "https://${var.app_web_name}.azurewebsites.net/"
    "Features:OrderReserveEnabled"             = false
    "Features:OrderReserveUrl"                 = ""
    "Features:OrderDeliveryEnabled"            = false
    "Features:OrderDeliveryUrl"                = ""
  }

  connection_string {
    name  = "CatalogConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
  }
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


# ----------- Connections -----------
# resource "azurerm_api_connection" "example" {
#   name                = "sql-connection"
#   resource_group_name = azurerm_resource_group.example.name
#   managed_api_id      = data.azurerm_managed_api.example.id
#   display_name        = "Example 1"

#   parameter_values = {
#     connectionString = azurerm_servicebus_namespace.example.default_primary_connection_string
#   }

#   lifecycle {
#     # NOTE: since the connectionString is a secure value it's not returned from the API
#     ignore_changes = ["parameter_values"]
#   }
# }