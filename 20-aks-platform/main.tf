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

data "azurerm_client_config" "current" {}

data "azurerm_resource_group" "main" {
  name = var.resource_group_name
}

data "azurerm_subnet" "aks" {
  name                 = "snet-aks-nodes"
  virtual_network_name = "vnet-aks-ent01-spoke-dev-krc"
  resource_group_name  = var.resource_group_name
}

data "azurerm_log_analytics_workspace" "main" {
  name                = "law-aks-ent01-dev-krc"
  resource_group_name = var.resource_group_name
}

variable "subscription_id" { type = string }
variable "resource_group_name" {
  type    = string
  default = "rg-aks-ent01-dev-krc"
}

variable "location" {
  type    = string
  default = "koreacentral"
}
variable "ssh_public_key" { type = string }
variable "admin_group_object_ids" {
  type    = list(string)
  default = []
}

resource "azurerm_container_registry" "main" {
  name                = "acraksent01dev"
  resource_group_name = data.azurerm_resource_group.main.name
  location            = var.location
  sku                 = "Standard"
  admin_enabled       = false
}

resource "azurerm_key_vault" "main" {
  name                       = "kv-aks-ent01-dev-krc"
  location                   = var.location
  resource_group_name        = data.azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  rbac_authorization_enabled = true
  purge_protection_enabled   = false
}

resource "azurerm_kubernetes_cluster" "main" {
  name                = "aks-aks-ent01-dev-krc"
  location            = var.location
  resource_group_name = data.azurerm_resource_group.main.name
  dns_prefix          = "aks-ent01-dev"
  kubernetes_version  = null

  private_cluster_enabled = false
  local_account_disabled  = false
  oidc_issuer_enabled     = true
  workload_identity_enabled = true

  default_node_pool {
    name                 = "system"
    vm_size              = "Standard_D4s_v5"
    node_count           = 2
    vnet_subnet_id       = data.azurerm_subnet.aks.id
    auto_scaling_enabled = false
    os_disk_size_gb      = 64
    type                 = "VirtualMachineScaleSets"
  }

  identity {
    type = "SystemAssigned"
  }

  linux_profile {
    admin_username = "azureuser"
    ssh_key {
      key_data = var.ssh_public_key
    }
  }

  network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_policy      = "cilium"
    network_data_plane  = "cilium"
    load_balancer_sku   = "standard"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.240.0.0/16"
    dns_service_ip      = "10.240.0.10"
  }

  azure_active_directory_role_based_access_control {
    azure_rbac_enabled     = true
    admin_group_object_ids = var.admin_group_object_ids
  }

  oms_agent {
    log_analytics_workspace_id = data.azurerm_log_analytics_workspace.main.id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }
}

resource "azurerm_role_assignment" "aks_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.main.kubelet_identity[0].object_id
}

output "aks_name" { value = azurerm_kubernetes_cluster.main.name }
output "acr_login_server" { value = azurerm_container_registry.main.login_server }
output "key_vault_name" { value = azurerm_key_vault.main.name }
