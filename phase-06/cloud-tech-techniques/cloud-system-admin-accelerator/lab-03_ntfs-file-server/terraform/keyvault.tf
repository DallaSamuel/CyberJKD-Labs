data "azurerm_client_config" "current" {}

resource "random_id" "kv_suffix" {
  byte_length = 4
}

resource "azurerm_key_vault" "lab_kv" {
  #checkov:skip=CKV_AZURE_189:Admin home IP rotates; public access kept with RBAC enforced. Production: private endpoint and public access disabled.
  #checkov:skip=CKV_AZURE_109:A firewall allow-list would lock out a rotating admin IP. Production: private endpoint.
  #checkov:skip=CKV2_AZURE_32:Private endpoint adds recurring cost; documented as a production change.
  name                       = "kv-fslab-${random_id.kv_suffix.hex}"
  location                   = azurerm_resource_group.rg.location
  resource_group_name        = azurerm_resource_group.rg.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  enable_rbac_authorization  = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = true

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_role_assignment" "kv_deployer_access" {
  scope                = azurerm_key_vault.lab_kv.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

resource "time_sleep" "wait_for_kv_role" {
  create_duration = "60s"
  depends_on      = [azurerm_role_assignment.kv_deployer_access]
}

resource "azurerm_key_vault_secret" "admin_password" {
  name            = "vm-admin-password"
  value           = var.admin_password
  key_vault_id    = azurerm_key_vault.lab_kv.id
  content_type    = "text/plain"
  expiration_date = "2027-01-01T00:00:00Z"
  depends_on      = [time_sleep.wait_for_kv_role]

  tags = {
    ManagedBy = "Terraform"
  }
}
