# Create application service plan
resource "azurerm_service_plan" "windows-weu" {
  name                = "asp-eshop-cloudx-weu"
  resource_group_name = azurerm_resource_group.this.name
  location            = "West Europe"
  sku_name            = "S1"
  os_type             = "Windows"
}

# ----------- Web -----------
# Create application insights for Web
resource "azurerm_application_insights" "web-weu" {
  name                = "appi-web-eshop-cloudx-weu"
  location            = azurerm_service_plan.windows-weu.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
}

# Create web app for Web
resource "azurerm_windows_web_app" "web-weu" {
  name                = "${var.app_web_name}-weu"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_service_plan.windows-weu.location
  service_plan_id     = azurerm_service_plan.windows-weu.id

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
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.web-weu.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.web-weu.connection_string
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
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
  }
}

resource "azurerm_windows_web_app_slot" "web-weu-slot" {
  name           = "slot"
  app_service_id = azurerm_windows_web_app.web-weu.id

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
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.web-weu.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.web-weu.connection_string
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
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
  }
}

# ----------- Web Access Policy & Role Assignments -----------
data "azuread_service_principal" "web-weu" {
  display_name = azurerm_windows_web_app.web-weu.name
  depends_on = [
    azurerm_windows_web_app.web-weu
  ]
}
resource "azurerm_key_vault_access_policy" "web-weu" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.web-weu.object_id

  secret_permissions = ["Get", "List" ]
  certificate_permissions = [ "Get", "List" ]
  key_permissions = [ "Get", "List" ]
}

data "azuread_service_principal" "web-weu-slot" {
  display_name = "${azurerm_windows_web_app.web-weu.name}/slots/${azurerm_windows_web_app_slot.web-weu-slot.name}"
  depends_on = [
    azurerm_windows_web_app_slot.web-weu-slot
  ]
}
resource "azurerm_key_vault_access_policy" "web-weu-slot" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.web-weu-slot.object_id

  secret_permissions = ["Get", "List" ]
  certificate_permissions = [ "Get", "List" ]
  key_permissions = [ "Get", "List" ]
}

# ------ 
resource "azurerm_monitor_autoscale_setting" "windows-weu" {
  name                = "Web Eus Autoscale Setting"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  target_resource_id  = azurerm_service_plan.windows-weu.id
  profile {
    name = "default"
    capacity {
      default = 1
      minimum = 1
      maximum = 5
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.windows-weu.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "GreaterThan"
        threshold          = 90
      }
      scale_action {
        direction = "Increase"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
    rule {
      metric_trigger {
        metric_name        = "CpuPercentage"
        metric_resource_id = azurerm_service_plan.windows-weu.id
        time_grain         = "PT1M"
        statistic          = "Average"
        time_window        = "PT5M"
        time_aggregation   = "Average"
        operator           = "LessThan"
        threshold          = 10
      }
      scale_action {
        direction = "Decrease"
        type      = "ChangeCount"
        value     = "1"
        cooldown  = "PT1M"
      }
    }
  }  
}
