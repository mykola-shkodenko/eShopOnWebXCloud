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

data "azurerm_cosmosdb_account" "this" {
  name                = azurerm_cosmosdb_account.this.name
  resource_group_name = azurerm_resource_group.this.name
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

# resource "azurerm_role_assignment" "cosmos-web-weu" {
#   scope                = azurerm_cosmosdb_account.this.id
#   role_definition_name = "Cosmos DB Operator"
#   principal_id         = azurerm_windows_web_app.web-weu.identity.0.principal_id
# }
# resource "azurerm_role_assignment" "cosmos-web-neu" {
#   scope                = azurerm_cosmosdb_account.this.id
#   role_definition_name = "Cosmos DB Operator"
#   principal_id         = azurerm_windows_web_app.web-neu.identity.0.principal_id
# }

# resource "azurerm_role_assignment" "cosmos-funcs" {
#   scope                = azurerm_cosmosdb_account.this.id
#   role_definition_name = "Cosmos DB Operator"
#   principal_id         = azurerm_windows_function_app.func-app.identity.0.principal_id
# }

# resource "azurerm_cosmosdb_sql_role_assignment" "cosmos-funcs" {
#   resource_group_name = azurerm_resource_group.this.name
#   account_name        = azurerm_cosmosdb_account.this.name  
#   role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
#   principal_id        = azurerm_windows_function_app.func-app.identity.0.principal_id
#   scope               = azurerm_cosmosdb_account.this.id
# }

# resource "azurerm_cosmosdb_sql_role_definition" "contributor" {
#   name                = "Cosmos DB Contributor"
#   resource_group_name = azurerm_resource_group.this.name
#   account_name        = azurerm_cosmosdb_account.this.name
#   type                = "CustomRole"
#   assignable_scopes   = [azurerm_cosmosdb_account.this.id]

#   permissions {
#     data_actions = [
#       "Microsoft.DocumentDB/databaseAccounts/readMetadata",
#       "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*",
#       "Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*"
#       ]
#   }
# }

# resource "azurerm_cosmosdb_sql_role_assignment" "cosmos-contributor-current" {
#   resource_group_name = azurerm_resource_group.this.name
#   account_name        = azurerm_cosmosdb_account.this.name
#   role_definition_id  = azurerm_cosmosdb_sql_role_definition.contributor.id
#   principal_id        = data.azurerm_client_config.current.object_id
#   scope               = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.this.name}/providers/Microsoft.DocumentDB/databaseAccounts/${azurerm_cosmosdb_account.this.name}"
# }

# resource "azurerm_cosmosdb_sql_role_assignment" "cosmos-db-data-contributor" {
#   resource_group_name = azurerm_resource_group.this.name
#   account_name        = azurerm_cosmosdb_account.this.name  
#   role_definition_id  = "${azurerm_cosmosdb_account.this.id}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
#   principal_id        =  data.azurerm_client_config.current.object_id
#   scope               = azurerm_cosmosdb_account.this.id
# }

resource "azurerm_cosmosdb_sql_role_assignment" "cosmos-db-data-contributor" {
  resource_group_name = azurerm_resource_group.this.name
  account_name        = azurerm_cosmosdb_account.this.name  
  scope               = azurerm_cosmosdb_account.this.id
  role_definition_id  = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${azurerm_resource_group.this.name}/providers/Microsoft.DocumentDB/databaseAccounts/${azurerm_cosmosdb_account.this.name}/sqlRoleDefinitions/00000000-0000-0000-0000-000000000002"
  principal_id        =  azurerm_windows_function_app.func-app.identity.0.principal_id
  
}

