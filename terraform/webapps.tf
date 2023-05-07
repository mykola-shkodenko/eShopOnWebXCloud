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
    "Features:OrderReserveEnabled"             = true
    "Features:OrderReserveTopicEnpoint"        = "${azurerm_eventgrid_topic.evgt-reserved.endpoint}"
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
