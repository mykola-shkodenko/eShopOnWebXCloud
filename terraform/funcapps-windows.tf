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
    ORDERS_CONTAINER_URL                  = "${azurerm_storage_account.st-acc.primary_blob_endpoint}orders"
    COSMOS_ENDPOINT                       = ""
    COSMOS_DATABASE                       = "eShopOnWebDb"
    COSMOS_ORDERS_CONTAINER               = "orders"
    EVENTGRID_ORDER_FAILED_TOPIC_ENDPOINT = "${azurerm_eventgrid_topic.evgt-failed.endpoint}"
  }
}

# ----------- Role assignments -----------

resource "azurerm_role_assignment" "ars-evgt-failed-func-app" {
  scope                = azurerm_eventgrid_topic.evgt-failed.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}