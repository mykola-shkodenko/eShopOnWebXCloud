# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "acreshopcloudx"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_resource_group.rg-cloudx.location
  sku                 = "Basic"
  admin_enabled       = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_key_vault_secret" "kvs-acr-user" {
  name         = "acr-admin-name"
  value        = azurerm_container_registry.acr.admin_username
  key_vault_id = azurerm_key_vault.kv.id
}

resource "azurerm_key_vault_secret" "kvs-acr-pass" {
  name         = "acr-admin-pass"
  value        = azurerm_container_registry.acr.admin_password
  key_vault_id = azurerm_key_vault.kv.id
}


resource "azurerm_service_plan" "asp-web" {
  name                = "asp-linux-eshop-cloudx"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_resource_group.rg-cloudx.location
  sku_name            = "B1"
  os_type             = "Linux"
}

# ----------- Public API -----------
# Create application insights for PublicAPI
resource "azurerm_application_insights" "appi-publicapi" {
  name                = "appi-public-eshop-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  application_type    = "web"
}

# Create web app for Public API
resource "azurerm_linux_web_app" "app-publicapi" {
  name                = var.app_publicapi_name
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  service_plan_id     = azurerm_service_plan.asp-web.id

  site_config {
    always_on = false    
    # container_registry_use_managed_identity = true # TODO: continues deployment should enabled
    # container_registry_managed_identity_client_id = azurerm_container_registry.acr.identity[0].principal_id # check !!!
    application_stack {
      docker_image     = "${azurerm_container_registry.acr.login_server}/publicapi"
      docker_image_tag = "latest"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL                 = azurerm_container_registry.acr.login_server
    DOCKER_REGISTRY_SERVER_USERNAME            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-user.name})"
    DOCKER_REGISTRY_SERVER_PASSWORD            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-pass.name})"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.appi-publicapi.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.appi-publicapi.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
  }

  connection_string {
    name  = "CatalogConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
  }
}

resource "azurerm_role_assignment" "ara-acr-app-publicapi" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app-publicapi.identity.0.principal_id
}

resource "azurerm_container_registry_webhook" "acrwh-publicapi" {
  name                = "webhookpublicapi"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  registry_name       = azurerm_container_registry.acr.name

  service_uri = "https://${var.app_publicapi_name}.azurewebsites.net/api" # URL is not correct. Correct should be created (Terraform doesn't provide)
  status      = "enabled"
  scope       = "publicapi:*"
  actions     = ["push"]
  custom_headers = {
    "Content-Type" = "application/json"
  }
}

# ----------- Web -----------
# Create application insights for Web
resource "azurerm_application_insights" "appi-web" {
  name                = "appi-web-eshop-cloudx"
  location            = azurerm_resource_group.rg-cloudx.location
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  application_type    = "web"
}

# Create web app for Web
resource "azurerm_linux_web_app" "app-web" {
  name                = var.app_web_name
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  service_plan_id     = azurerm_service_plan.asp-web.id

  site_config {
    always_on = false
    # container_registry_use_managed_identity = true 
    # container_registry_managed_identity_client_id = azurerm_container_registry.acr.identity[0].principal_id # check !!!
    application_stack {
      docker_image     = "${azurerm_container_registry.acr.login_server}/web"
      docker_image_tag = "latest"
      # dotnet_version   = "v7.0"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL                 = azurerm_container_registry.acr.login_server
    DOCKER_REGISTRY_SERVER_USERNAME            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-user.name})"
    DOCKER_REGISTRY_SERVER_PASSWORD            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-pass.name})"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.appi-web.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.appi-web.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
    baseUrls__apiBase                          = "https://${var.app_publicapi_name}.azurewebsites.net/api/"
    baseUrls__webBase                          = "https://${var.app_web_name}.azurewebsites.net/"
    Features__OrderReserveEnabled              = true
    Features__OrderReserveTopicEnpoint         = "${azurerm_eventgrid_topic.evgt-reserved.endpoint}"
    Features__OrderDeliveryEnabled             = false
    Features__OrderDeliveryUrl                 = ""
  }

  connection_string {
    name  = "CatalogConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-db-connection.name})"
  }

  logs {
    application_logs {
      file_system_level = "Information"
    }
  }
}

resource "azurerm_role_assignment" "ara-acr-app-web" {
  scope                = azurerm_container_registry.acr.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_linux_web_app.app-web.identity.0.principal_id
}

resource "azurerm_container_registry_webhook" "acrwh-web" {
  name                = "webhookweb"
  resource_group_name = azurerm_resource_group.rg-cloudx.name
  location            = azurerm_service_plan.asp-web.location
  registry_name       = azurerm_container_registry.acr.name

  service_uri = "https://${var.app_web_name}.azurewebsites.net/api"
  status      = "enabled"
  scope       = "web:*"
  actions     = ["push"]
  custom_headers = {
    "Content-Type" = "application/json"
  }
}

# ----------- Public API Access Policy & Role Assignments -----------
data "azuread_service_principal" "asp-linux-publicapi" {
  display_name = azurerm_linux_web_app.app-publicapi.name
  depends_on = [
    azurerm_linux_web_app.app-publicapi
  ]
}
resource "azurerm_key_vault_access_policy" "kvap-publicapi" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.asp-linux-publicapi.object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "List"
  ]
}

# resource "azurerm_role_assignment" "ara-acr-publicapi" {
#   scope                = azurerm_container_registry.acr.id
#   role_definition_name = "Reader"
#   principal_id         = azurerm_linux_web_app.app-publicapi.identity[0].principal_id
# }

# ----------- Web Access Policy & Role Assignments -----------
data "azuread_service_principal" "asp-linux-web" {
  display_name = azurerm_linux_web_app.app-web.name
  depends_on = [
    azurerm_linux_web_app.app-web
  ]
}
resource "azurerm_key_vault_access_policy" "kvap-web" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azuread_service_principal.asp-linux-web.object_id

  secret_permissions = [
    "Get",
    "List"
  ]

  certificate_permissions = [
    "Get",
    "List"
  ]

  key_permissions = [
    "Get",
    "List"
  ]
}

resource "azurerm_role_assignment" "ara-evgt-reserved-web-app" {
  scope                = azurerm_eventgrid_topic.evgt-reserved.id
  role_definition_name = "EventGrid Data Sender"
  principal_id         = azurerm_linux_web_app.app-web.identity[0].principal_id
}

# resource "azurerm_role_assignment" "ara-acr-web" {
#   scope                = azurerm_container_registry.acr.id
#   role_definition_name = "Reader"
#   principal_id         = azurerm_linux_web_app.app-web.identity[0].principal_id
# }