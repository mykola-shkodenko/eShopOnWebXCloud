# Create application service plan
resource "azurerm_service_plan" "windows-neu" {
  name                = "asp-eshop-cloudx-neu"
  resource_group_name = azurerm_resource_group.this.name
  location            = "North Europe"
  sku_name            = "F1"
  os_type             = "Windows"
}

# ----------- Web -----------
# Create application insights for Web
resource "azurerm_application_insights" "web-neu" {
  name                = "appi-web-eshop-cloudx-neu"
  location            = azurerm_service_plan.windows-neu.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
}

# Create web app for Web
resource "azurerm_windows_web_app" "web-neu" {
  name                = "${var.app_web_name}-neu"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_service_plan.windows-neu.location
  service_plan_id     = azurerm_service_plan.windows-neu.id

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
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.web-eus.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.web-eus.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
    "baseUrls:apiBase"                         = "https://${var.app_publicapi_name}.azurewebsites.net/api/"
    "baseUrls:webBase"                         = "https://${var.app_web_name}.azurewebsites.net/"
    "Features:OrderReserveEnabled"             = true
    "Features:AzureServiceBusFullNamespace"    = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
    "Features:OrderReserverQueueName"          = azurerm_servicebus_queue.order-reservation-requested.name
    "Features:OrderDeliveryEnabled"            = true
    "Features:OrderDeliveryUrl"                = "https://${var.func_app_name}.azurewebsites.net/api/OrderDeliveryProcessor?code=${data.azurerm_function_app_host_keys.this.default_function_key}"
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

# ----------- Web Access Policy & Role Assignments -----------
data "azuread_service_principal" "web-neu" {
  display_name = azurerm_windows_web_app.web-neu.name
  depends_on = [
    azurerm_windows_web_app.web-neu
  ]
}
resource "azurerm_key_vault_access_policy" "web-neu" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.web-neu.object_id

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
