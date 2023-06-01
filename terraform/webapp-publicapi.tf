# Container Registry
resource "azurerm_container_registry" "acr" {
  name                = "acreshopcloudx"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku                 = "Basic"
  admin_enabled       = true

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_service_plan" "asp-linux" {
  name                = "asp-linux-eshop-cloudx"
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_resource_group.this.location
  sku_name            = "B1"
  os_type             = "Linux"
}

# ----------- Public API -----------
# Create application insights for PublicAPI
resource "azurerm_application_insights" "publicapi" {
  name                = "appi-public-eshop-cloudx"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  application_type    = "web"
}

# Create web app for Public API
resource "azurerm_linux_web_app" "app-publicapi" {
  name                = var.app_publicapi_name
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_service_plan.asp-linux.location
  service_plan_id     = azurerm_service_plan.asp-linux.id

  site_config {
    always_on                                     = false
    container_registry_use_managed_identity       = true
    container_registry_managed_identity_client_id = azurerm_container_registry.acr.identity[0].principal_id
    application_stack {
      docker_image     = "${azurerm_container_registry.acr.login_server}/publicapi"
      docker_image_tag = "latest"
    }
  }

  identity {
    type = "SystemAssigned"
  }

  app_settings = {
    DOCKER_REGISTRY_SERVER_URL = azurerm_container_registry.acr.login_server
    # DOCKER_REGISTRY_SERVER_USERNAME            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-user.name})"
    # DOCKER_REGISTRY_SERVER_PASSWORD            = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${azurerm_key_vault_secret.kvs-acr-pass.name})"
    APPINSIGHTS_INSTRUMENTATIONKEY             = azurerm_application_insights.publicapi.instrumentation_key
    APPLICATIONINSIGHTS_CONNECTION_STRING      = azurerm_application_insights.publicapi.connection_string
    ApplicationInsightsAgent_EXTENSION_VERSION = "~2"
  }

  connection_string {
    name  = "CatalogConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
  }

  connection_string {
    name  = "IdentityConnection"
    type  = "SQLServer"
    value = "@Microsoft.KeyVault(VaultName=${azurerm_key_vault.kv.name};SecretName=${data.azurerm_key_vault_secret.db-connection.name})"
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
  resource_group_name = azurerm_resource_group.this.name
  location            = azurerm_service_plan.asp-linux.location
  registry_name       = azurerm_container_registry.acr.name

  service_uri = "https://${azurerm_linux_web_app.app-publicapi.site_credential.0.name}:${azurerm_linux_web_app.app-publicapi.site_credential.0.password}@${lower(azurerm_linux_web_app.app-publicapi.name)}.scm.azurewebsites.net/docker/hook"
  status      = "enabled"
  scope       = "publicapi:*"
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