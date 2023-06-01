resource "azurerm_traffic_manager_profile" "web" {
  name                   = "traf-web-eshop-cloudx"
  resource_group_name    = azurerm_resource_group.this.name
  traffic_routing_method = "Performance"

  dns_config {
    relative_name = "traf-web-eshop-cloudx"
    ttl           = 60
  }

  monitor_config {
    protocol                     = "HTTP"
    port                         = 80
    path                         = "/"
    interval_in_seconds          = 30
    timeout_in_seconds           = 10
    tolerated_number_of_failures = 3
  }
}


resource "azurerm_traffic_manager_azure_endpoint" "web-weu" {
  name               = "Web Eus"
  profile_id         = azurerm_traffic_manager_profile.web.id
  target_resource_id = azurerm_windows_web_app.web-weu.id
  priority           = 1
  weight             = 1
}

resource "azurerm_traffic_manager_azure_endpoint" "web-neu" {
  name               = "Web Neu"
  profile_id         = azurerm_traffic_manager_profile.web.id
  target_resource_id = azurerm_windows_web_app.web-neu.id
  weight             = 1
  priority           = 2
}