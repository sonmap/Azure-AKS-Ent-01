terraform {
  required_version = ">= 1.6.0"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.13"
    }
  }
}

provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

variable "subscription_id" { type = string }
variable "resource_group_name" { type = string; default = "rg-aks-ent01-dev-krc" }
variable "aks_name" { type = string; default = "aks-aks-ent01-dev-krc" }

resource "azurerm_kubernetes_cluster_extension" "flux_placeholder" {
  name           = "cluster-platform-ready"
  cluster_id     = data.azurerm_kubernetes_cluster.main.id
  extension_type = "microsoft.flux"
  release_train  = "Stable"
  configuration_settings = {
    "image-automation-controller.enabled" = "false"
    "image-reflector-controller.enabled"  = "false"
  }
}

data "azurerm_kubernetes_cluster" "main" {
  name                = var.aks_name
  resource_group_name = var.resource_group_name
}

provider "helm" {
  kubernetes {
    host                   = data.azurerm_kubernetes_cluster.main.kube_config[0].host
    client_certificate     = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_certificate)
    client_key             = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].client_key)
    cluster_ca_certificate = base64decode(data.azurerm_kubernetes_cluster.main.kube_config[0].cluster_ca_certificate)
  }
}

resource "helm_release" "argocd" {
  name             = "argocd"
  repository       = "https://argoproj.github.io/argo-helm"
  chart            = "argo-cd"
  namespace        = "argocd"
  create_namespace = true

  set {
    name  = "server.service.type"
    value = "ClusterIP"
  }
}

resource "helm_release" "jenkins" {
  name             = "jenkins"
  repository       = "https://charts.jenkins.io"
  chart            = "jenkins"
  namespace        = "jenkins"
  create_namespace = true

  set {
    name  = "controller.serviceType"
    value = "ClusterIP"
  }

  set {
    name  = "controller.installPlugins[0]"
    value = "kubernetes"
  }

  set {
    name  = "controller.installPlugins[1]"
    value = "workflow-aggregator"
  }

  set {
    name  = "persistence.size"
    value = "32Gi"
  }
}
