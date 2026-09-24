variable "location" {
  type    = string
  default = "Central US"
}

variable "resource_group_name" {
  type    = string
  default = "RG-FileServerLab"
}

variable "vnet_name" {
  type    = string
  default = "VNET-FileServerLab"
}

variable "subnet_name" {
  type    = string
  default = "Subnet-Servers"
}

variable "vnet_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "subnet_cidr" {
  type    = string
  default = "10.0.1.0/24"
}

variable "nsg_name" {
  type    = string
  default = "NSG-RDP"
}

variable "rdp_source" {
  type    = string
  default = "*"
}

variable "admin_username" {
  type    = string
  default = "azureadmin"
}

variable "admin_password" {
  type      = string
  sensitive = true
}

variable "server_vm_size" {
  type    = string
  default = "Standard_D2s_v7"
}

variable "client_vm_size" {
  type    = string
  default = "Standard_D2s_v7"
}


variable "enable_nat_gateway" {
  type    = bool
  default = true
}

variable "alert_email" {
  type = string
}

variable "monthly_budget" {
  type    = number
  default = 25
}

variable "log_daily_cap_gb" {
  type    = number
  default = 1
}
