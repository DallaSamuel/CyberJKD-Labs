resource "azurerm_resource_group" "rg" {
  name     = var.resource_group_name
  location = var.location
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = [var.vnet_cidr]
}

resource "time_sleep" "wait_after_vnet" {
  create_duration = "45s"
  depends_on      = [azurerm_virtual_network.vnet]
}

resource "azurerm_subnet" "subnet" {
  name                 = var.subnet_name
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = [var.subnet_cidr]
  depends_on           = [time_sleep.wait_after_vnet]
}

resource "azurerm_network_security_group" "nsg" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  security_rule {
    name                       = "Allow-RDP-3389"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_address_prefix      = var.rdp_source
    source_port_range          = "*"
    destination_port_range     = "3389"
    destination_address_prefix = "*"
  }

  depends_on = [time_sleep.wait_after_vnet]
}

resource "time_sleep" "wait_after_nsg" {
  create_duration = "45s"
  depends_on      = [azurerm_network_security_group.nsg]
}

resource "azurerm_subnet_network_security_group_association" "subnet" {
  subnet_id                 = azurerm_subnet.subnet.id
  network_security_group_id = azurerm_network_security_group.nsg.id
}

resource "azurerm_public_ip" "client01" {
  name                = "client01-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
  depends_on          = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface" "dc01" {
  name                = "dc01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.4"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_network_interface" "fs01" {
  name                = "fs01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
  }

  depends_on = [time_sleep.wait_after_nsg, azurerm_network_interface.dc01]
}

resource "azurerm_network_interface" "client01" {
  #checkov:skip=CKV_AZURE_119:Single RDP entry point locked to one source IP by the subnet NSG. Production: Azure Bastion or just-in-time access.
  name                = "client01-nic"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.client01.id
  }

  depends_on = [time_sleep.wait_after_nsg, azurerm_network_interface.dc01]
}

resource "azurerm_windows_virtual_machine" "dc01" {
  #checkov:skip=CKV_AZURE_50:Extensions required for run-command automation and the monitoring agent.
  name                              = "DC01"
  location                          = var.location
  resource_group_name               = azurerm_resource_group.rg.name
  size                              = var.server_vm_size
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.dc01.id]
  encryption_at_host_enabled        = true
  vm_agent_platform_updates_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_windows_virtual_machine" "fs01" {
  #checkov:skip=CKV_AZURE_50:Extensions required for run-command automation and the monitoring agent.
  name                              = "FS01"
  location                          = var.location
  resource_group_name               = azurerm_resource_group.rg.name
  size                              = var.server_vm_size
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.fs01.id]
  encryption_at_host_enabled        = true
  vm_agent_platform_updates_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_windows_virtual_machine" "client01" {
  #checkov:skip=CKV_AZURE_50:Extensions required for the RDP fix and run-command automation.
  name                              = "CLIENT01"
  location                          = var.location
  resource_group_name               = azurerm_resource_group.rg.name
  size                              = var.client_vm_size
  admin_username                    = var.admin_username
  admin_password                    = var.admin_password
  network_interface_ids             = [azurerm_network_interface.client01.id]
  encryption_at_host_enabled        = true
  vm_agent_platform_updates_enabled = true

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsDesktop"
    offer     = "windows-11"
    sku       = "win11-25h2-pro"
    version   = "latest"
  }

  depends_on = [time_sleep.wait_after_nsg]
}

resource "azurerm_virtual_machine_extension" "client01_enable_rdp" {
  name                       = "enable-rdp"
  virtual_machine_id         = azurerm_windows_virtual_machine.client01.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.10"
  auto_upgrade_minor_version = true

  settings = jsonencode({
    commandToExecute = "powershell -Command \"Set-ItemProperty -Path 'HKLM:\\System\\CurrentControlSet\\Control\\Terminal Server' -Name 'fDenyTSConnections' -Value 0; Enable-NetFirewallRule -DisplayGroup 'Remote Desktop'\""
  })
}
