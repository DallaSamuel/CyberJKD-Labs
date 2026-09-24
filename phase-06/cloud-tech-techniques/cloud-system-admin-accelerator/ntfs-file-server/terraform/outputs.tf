output "dc01_private_ip" {
  value       = azurerm_network_interface.dc01.private_ip_address
  description = "Always 10.0.1.4 - DC01 static DNS address."
}

output "client01_public_ip" {
  value       = azurerm_public_ip.client01.ip_address
  description = "RDP entry point, locked to one source IP."
}

output "key_vault_name" {
  value       = azurerm_key_vault.lab_kv.name
  description = "Key Vault holding the admin password."
}

output "log_analytics_workspace" {
  value       = azurerm_log_analytics_workspace.lab.name
  description = "Workspace for security event logs."
}
