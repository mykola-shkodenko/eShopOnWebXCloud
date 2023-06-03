resource "azurerm_servicebus_namespace" "this" {
  name                = "sbns-eshop-cloudx"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  sku                 = "Basic"
}

resource "azurerm_servicebus_queue" "order-reservation-requested" {
  name         = "sbq-order-reservation-requested"
  namespace_id = azurerm_servicebus_namespace.this.id

  enable_partitioning = true
}

resource "azurerm_servicebus_queue" "order-reservation-failed" {
  name         = "sbq-order-reservation-failed"
  namespace_id = azurerm_servicebus_namespace.this.id

  enable_partitioning = true
}

data "azurerm_servicebus_namespace" "this" {
  name                = azurerm_servicebus_namespace.this.name
  resource_group_name = azurerm_resource_group.this.name
}

# ----------- Role assignments -----------

resource "azurerm_role_assignment" "servicebus-order-reservation-requested--web-weu" {
  scope                = azurerm_servicebus_queue.order-reservation-requested.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_windows_web_app.web-weu.identity[0].principal_id
}

resource "azurerm_role_assignment" "servicebus-order-reservation-requested-web-nue" {
  scope                = azurerm_servicebus_queue.order-reservation-requested.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_windows_web_app.web-neu.identity[0].principal_id
}

resource "azurerm_role_assignment" "servicebus-order-reservation-requested-func-app" {
  scope                = azurerm_servicebus_queue.order-reservation-failed.id
  role_definition_name = "Azure Service Bus Data Receiver"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}

resource "azurerm_role_assignment" "servicebus-order-reservation-failed-func-app" {
  scope                = azurerm_servicebus_queue.order-reservation-failed.id
  role_definition_name = "Azure Service Bus Data Sender"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}