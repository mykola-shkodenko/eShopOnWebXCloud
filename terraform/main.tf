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

data "azurerm_client_config" "current" {}

# Create a resource group
resource "azurerm_resource_group" "rg-cloudx" {
  name     = "rg-events-eus"
  location = "East US"
  tags = {
    module = "Events"
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

resource "azurerm_role_assignment" "ars-st-acc-func-app" {
  scope                = azurerm_storage_account.st-acc.id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}

# ----------- Event Grid -----------
resource "azurerm_eventgrid_topic" "evgt-reserved" {
  name                = "evgt-order-reserved-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ars-evgt-reserved-web-app" {
  scope                = azurerm_eventgrid_topic.evgt-reserved.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_windows_web_app.app-web.identity[0].principal_id
}

resource "azurerm_eventgrid_topic" "evgt-failed" {
  name                = "evgt-order-failed-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_role_assignment" "ars-evgt-failed-func-app" {
  scope                = azurerm_eventgrid_topic.evgt-failed.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_windows_function_app.func-app.identity[0].principal_id
}

# ----------- Logic App -----------

# ----------- Second step teraform resources -----------
# resources should be uncommented befor second terraform apply
resource "azurerm_eventgrid_event_subscription" "evgs-reserved" {
  name  = "evgs-order-reserved-cloudx"
  scope = azurerm_eventgrid_topic.evgt-reserved.id
  azure_function_endpoint {
    function_id = "${azurerm_windows_function_app.func-app.id}/functions/${var.func_name_reserved}"
  }
}