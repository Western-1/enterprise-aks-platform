resource "azurerm_kubernetes_cluster" "aks" {
  name                            = var.name
  resource_group_name             = var.resource_group_name
  location                        = var.location
  dns_prefix                      = var.name
  kubernetes_version              = var.kubernetes_version
  node_resource_group             = var.node_resource_group
  sku_tier                        = var.sku_tier
  automatic_upgrade_channel       = "stable"
  azure_policy_enabled            = true
  oidc_issuer_enabled             = true
  workload_identity_enabled       = true

  api_server_access_profile {
    authorized_ip_ranges = var.api_server_authorized_ip_ranges
  }

  default_node_pool {
    name                 = "system"
    vm_size              = var.system_pool_vm_size
    node_count           = var.system_pool_node_count
    min_count            = var.system_pool_min_count
    max_count            = var.system_pool_max_count
    vnet_subnet_id       = var.aks_subnet_id
    orchestrator_version = var.kubernetes_version
    os_sku               = "AzureLinux"
  }

  identity {
    type = "SystemAssigned"
  }

network_profile {
    network_plugin      = "azure"
    network_plugin_mode = "overlay"
    network_data_plane  = "cilium"
    network_policy      = "cilium"
    outbound_type       = "loadBalancer"
    load_balancer_sku   = "standard"
    pod_cidr            = "10.244.0.0/16"
    service_cidr        = "10.96.0.0/16"
    dns_service_ip      = "10.96.0.10"
  }

  oms_agent {
    log_analytics_workspace_id = var.log_analytics_workspace_id
  }

  key_vault_secrets_provider {
    secret_rotation_enabled = true
  }

  tags = var.tags
}

resource "azurerm_kubernetes_cluster_node_pool" "user" {
  count                 = var.user_pool_enabled ? 1 : 0
  name                  = "user"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks.id
  vm_size               = var.user_pool_vm_size
  node_count            = var.user_pool_node_count
  min_count             = var.user_pool_min_count
  max_count             = var.user_pool_max_count
  auto_scaling_enabled  = true
  vnet_subnet_id        = var.aks_subnet_id
  node_taints           = var.user_pool_taints
  node_labels           = var.user_pool_labels
  os_sku                = "AzureLinux"

  orchestrator_version = var.kubernetes_version
}

resource "azurerm_role_assignment" "aks_pull_acr" {
  scope                = var.acr_id
  role_definition_name = "AcrPull"
  principal_id         = azurerm_kubernetes_cluster.aks.identity[0].principal_id
}