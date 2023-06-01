# ----------- Func App -----------
# Create application insights for func app
resource "azurerm_application_insights" "funcapp" {
  name                = "appi-funcapp-eshop-cloudx"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
}

# Create consumption app service plan
resource "azurerm_service_plan" "funcapp" {
  name                = "aps-funcapp-eshop-cloudx"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  os_type             = "Windows"
  sku_name            = "Y1"
}

# Create func app 
resource "azurerm_windows_function_app" "func-app" {
  name                       = var.func_app_name
  resource_group_name        = azurerm_resource_group.this.name
  location                   = azurerm_resource_group.this.location
  storage_account_name       = azurerm_storage_account.this.name
  storage_account_access_key = azurerm_storage_account.this.primary_access_key
  service_plan_id            = azurerm_service_plan.funcapp.id

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
    APPINSIGHTS_INSTRUMENTATIONKEY         = azurerm_application_insights.funcapp.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING  = azurerm_application_insights.funcapp.connection_string
    # WEBSITE_RUN_FROM_PACKAGE               = 1
    ORDERS_CONTAINER_URL                   = "${azurerm_storage_account.this.primary_blob_endpoint}orders"
    COSMOS_ENDPOINT                        = ""
    COSMOS_DATABASE                        = var.cosmos_db_name
    COSMOS_ORDERS_CONTAINER                = var.cosmos_container_name_orders
    AZURE_SERVICEBUS_FULL_NAMEPACE         = "${azurerm_servicebus_namespace.this.name}.servicebus.windows.net"
    AZURE_SERVICEBUS_ORDER_REQUESTED_QUEUE = azurerm_servicebus_queue.order-reservation-requested.name
    AZURE_SERVICEBUS_ORDER_FAILED_QUEUE    = azurerm_servicebus_queue.order-reservation-failed.name

  }
}

data "azurerm_function_app_host_keys" "this" {
  name                = azurerm_windows_function_app.func-app.name
  resource_group_name = azurerm_windows_function_app.func-app.resource_group_name

  # depends_on = [azurerm_windows_function_app.func-app]
}
