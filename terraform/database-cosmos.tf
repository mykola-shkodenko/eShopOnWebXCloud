resource "random_integer" "ri" {
  min = 10000
  max = 99999
}

resource "azurerm_cosmosdb_account" "this" {
  name                = "cosmos-eshop-cloudx"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  identity {
    type = "SystemAssigned"
  }

  consistency_policy {
    consistency_level       = "Session"
    max_interval_in_seconds = 5
    max_staleness_prefix    = 100
  }

  geo_location {
    location          = azurerm_resource_group.this.location
    failover_priority = 0
  }

  capacity {
    total_throughput_limit = 1000
  }

}

resource "azurerm_cosmosdb_sql_database" "main" {
  name                = var.cosmos_db_name
  resource_group_name = azurerm_cosmosdb_account.this.resource_group_name
  account_name        = azurerm_cosmosdb_account.this.name
}

resource "azurerm_cosmosdb_sql_container" "orders" {
  name                  = var.cosmos_container_name_orders
  resource_group_name   = azurerm_cosmosdb_account.this.resource_group_name
  account_name          = azurerm_cosmosdb_account.this.name
  database_name         = azurerm_cosmosdb_sql_database.main.name
  partition_key_path    = "/orderId"
  partition_key_version = 1
  throughput            = 400
}

resource "azurerm_role_assignment" "cosmos-web-eus" {
  scope                = azurerm_cosmosdb_account.this.id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azurerm_windows_web_app.web-eus.identity.0.principal_id
}
resource "azurerm_role_assignment" "cosmos-web-neu" {
  scope                = azurerm_cosmosdb_account.this.id
  role_definition_name = "Cosmos DB Operator"
  principal_id         = azurerm_windows_web_app.web-neu.identity.0.principal_id
}

resource "azurerm_role_assignment" "cosmos-funcs" {
  scope                = azurerm_cosmosdb_account.this.id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = azurerm_windows_function_app.func-app.identity.0.principal_id
}