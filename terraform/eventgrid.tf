# ----------- Event Grid -----------
resource "azurerm_eventgrid_topic" "evgt-reserved" {
  name                = "evgt-order-reserved-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_eventgrid_topic" "evgt-failed" {
  name                = "evgt-order-failed-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name

  identity {
    type = "SystemAssigned"
  }
}