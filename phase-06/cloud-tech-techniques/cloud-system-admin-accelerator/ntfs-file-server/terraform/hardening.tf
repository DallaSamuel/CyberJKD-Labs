resource "azurerm_public_ip" "nat" {
  count               = var.enable_nat_gateway ? 1 : 0
  name                = "nat-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

resource "azurerm_nat_gateway" "nat" {
  count                   = var.enable_nat_gateway ? 1 : 0
  name                    = "natgw-fslab"
  location                = var.location
  resource_group_name     = azurerm_resource_group.rg.name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
}

resource "azurerm_nat_gateway_public_ip_association" "nat" {
  count                = var.enable_nat_gateway ? 1 : 0
  nat_gateway_id       = azurerm_nat_gateway.nat[0].id
  public_ip_address_id = azurerm_public_ip.nat[0].id
}

resource "azurerm_subnet_nat_gateway_association" "nat" {
  count          = var.enable_nat_gateway ? 1 : 0
  subnet_id      = azurerm_subnet.subnet.id
  nat_gateway_id = azurerm_nat_gateway.nat[0].id
}

resource "azurerm_log_analytics_workspace" "lab" {
  name                = "law-fslab"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
  daily_quota_gb      = var.log_daily_cap_gb

  tags = {
    Environment = "Lab"
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_dev_test_global_vm_shutdown_schedule" "vm" {
  for_each = {
    dc01     = azurerm_windows_virtual_machine.dc01.id
    fs01     = azurerm_windows_virtual_machine.fs01.id
    client01 = azurerm_windows_virtual_machine.client01.id
  }

  virtual_machine_id    = each.value
  location              = var.location
  enabled               = true
  daily_recurrence_time = "2300"
  timezone              = "W. Central Africa Standard Time"

  notification_settings {
    enabled = false
  }
}

resource "azurerm_consumption_budget_resource_group" "lab" {
  name              = "budget-fslab"
  resource_group_id = azurerm_resource_group.rg.id
  amount            = var.monthly_budget
  time_grain        = "Monthly"

  time_period {
    start_date = "2026-09-01T00:00:00Z"
  }

  notification {
    enabled        = true
    threshold      = 80
    operator       = "GreaterThan"
    contact_emails = [var.alert_email]
  }

  notification {
    enabled        = true
    threshold      = 100
    operator       = "GreaterThan"
    contact_emails = [var.alert_email]
  }
}
