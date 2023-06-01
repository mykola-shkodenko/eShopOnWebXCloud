data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "this" {
  name     = "rg-final-weu"
  location = "West Europe"
  tags = {
    module = "final"
  }
}

# Create storage account
resource "azurerm_storage_account" "this" {
  name                     = "storageeshopcloudx"
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_role_assignment" "storage-func-app" {
  scope                = azurerm_storage_account.this.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}


# ----------- Logic App -----------

# ----------- Second step teraform resources -----------
# resources should be uncommented befor second terraform apply

/*
resource "azurerm_eventgrid_event_subscription" "evgs-reserved" {
  name  = "evgs-order-reserved-cloudx"
  scope = azurerm_eventgrid_topic.evgt-reserved.id
  azure_function_endpoint {
    function_id = "${azurerm_windows_function_app.func-app.id}/functions/${var.func_name_reserved}"
  }
}
*/