terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
  default     = "18fbfa69-3481-4395-845e-d3f7d4583562"
}
variable "resource_group_name" {
  type    = string
  default = "rg-aks-ent01-dev-krc"
}

variable "location" {
  type    = string
  default = "koreacentral"
}

resource "azurerm_virtual_network" "hub" {
  name                = "vnet-aks-ent01-hub-dev-krc"
  address_space       = ["10.10.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_virtual_network" "spoke" {
  name                = "vnet-aks-ent01-spoke-dev-krc"
  address_space       = ["10.20.0.0/16"]
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_subnet" "agent" {
  name                 = "snet-devops-agent"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.hub.name
  address_prefixes     = ["10.10.2.0/24"]
}

resource "azurerm_subnet" "aks" {
  name                 = "snet-aks-nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.20.0.0/22"]
}

resource "azurerm_subnet" "private_endpoint" {
  name                 = "snet-private-endpoint"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.spoke.name
  address_prefixes     = ["10.20.5.0/24"]
}

resource "azurerm_network_security_group" "aks" {
  name                = "nsg-aks-ent01-nodes"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "AllowHubManagement"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_ranges    = ["443", "22"]
    source_address_prefix      = "10.10.0.0/16"
    destination_address_prefix = "10.20.0.0/22"
  }
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = azurerm_subnet.aks.id
  network_security_group_id = azurerm_network_security_group.aks.id
}

resource "azurerm_virtual_network_peering" "hub_to_spoke" {
  name                      = "peer-hub-to-spoke"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.hub.name
  remote_virtual_network_id = azurerm_virtual_network.spoke.id
}

resource "azurerm_virtual_network_peering" "spoke_to_hub" {
  name                      = "peer-spoke-to-hub"
  resource_group_name       = var.resource_group_name
  virtual_network_name      = azurerm_virtual_network.spoke.name
  remote_virtual_network_id = azurerm_virtual_network.hub.id
}

output "aks_subnet_id" { value = azurerm_subnet.aks.id }
output "spoke_vnet_id" { value = azurerm_virtual_network.spoke.id }
