################################################################################
# 1. F5 DISTRIBUTED CLOUD (XC) API CREDENTIALS
################################################################################

# Path to your F5 XC API credential file (p12)
api_p12_file = "your-tenant.console.ves.volterra.io.api-creds.p12"

# URL for the F5 XC API
api_url = "https://your-tenant.console.ves.volterra.io/api"

################################################################################
# 2. DEPLOYMENT MODEL & SITE CONFIGURATION
################################################################################

# The logical deployment model.
# - "cluster": Creates 1 XC site object. HA is enabled if num_nodes = 3.
# - "vsite":   Creates 1 XC site object PER NODE (e.g., 3 nodes = 3 sites).
#              These sites are grouped by a single virtual_site. HA is
#              always disabled for each site object.
deployment_model = "vsite"

#-------------------------------------------------------------------------------
# IMPORTANT NOTE ON DEPLOYMENT MODEL:
#
# "cluster": Use this for a standard single-site or 3-node HA deployment.
#   - 1 or 3 nodes.
#   - 1 `volterra_securemesh_site_v2` resource.
#   - 1 `volterra_token` (shared by all nodes).
#
# "vsite": Use this to deploy multiple, independent nodes as a single logical group.
#   - 1, 2, or 3 nodes.
#   - Creates `num_nodes` (e.g., 2) `volterra_securemesh_site_v2` resources.
#   - Creates `num_nodes` (e.g., 2) `volterra_token` resources (one per node).
#   - Creates 1 `volterra_virtual_site` to group them all.
#-------------------------------------------------------------------------------

# Base name for the site(s) and Azure resources. Must be a valid DNS-1035 label.
cluster_name = "f5-xc-azure-site"

# Number of CE nodes to deploy.
# - If deployment_model = "cluster", must be 1 or 3.
# - If deployment_model = "vsite", can be 1, 2, or 3.
num_nodes = 1

# Number of network interfaces (NICs) per node.
# - 1 = Single-NIC (SLO only)
# - 2 = Dual-NIC (SLO + SLI)
num_nics = 2

################################################################################
# 3. AZURE COMPUTE & IMAGE CONFIGURATION
################################################################################

# Azure Region where resources will be deployed
location = "Germany West Central"

# Azure VM Instance Size (medium node : "Standard_D8_v4" | Ref : https://docs.cloud.f5.com/docs-v2/multi-cloud-network-connect/reference/ce-site-size-ref)
# (Medium: 8 vCPUs and 32 GB RAM - Standard_D8_v4)
# (Large: 16 vCPUs and 64 GB RAM - Standard_D16_v4)
vm_size = "Standard_D8_v4"

# Azure Image details for the F5 XC CE nodes
image = {
  publisher = "f5-networks"
  offer     = "f5xc_customer_edge"
  sku       = "f5xccebyol"
  version   = "9.2025.17" # Replace with latest version from F5 XC documentation
}

# Root disk configuration for each node
os_disk = {
  size_gb = 80             # Disk size in GB (min 120 GB)
  type    = "Standard_LRS" # Azure Storage Account type (Standard_LRS, Premium_LRS, etc.)
}

# Azure Availability Zones. 
# NOTE: The number of items in this list MUST match 'num_nodes'.
az_name = [
  "1", # For node-1
  # "2", # For node-2 (uncomment if num_nodes > 1)
  # "3", # For node-3 (uncomment if num_nodes = 3)
]

# Custom tags to apply to all created Azure resources
tags = {
  Environment = "Development"
  Project     = "F5XC"
  Owner       = "user@example.com"
}

################################################################################
# 4. AZURE NETWORKING & SECURITY CONFIGURATION
################################################################################

# Resource Group and VNet where the nodes will be deployed
resource_group_name = "your-resource-group"
vnet_name           = "your-vnet-name"

# --- Site Local Outside (SLO) Network ---
# Subnet Resource IDs for the SLO (eth0) interface.
# NOTE: The number of items in this list MUST match 'num_nodes'.
slo_subnet_ids = [
  "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/slo-1",
  # "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/slo-2",
  # "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/slo-3"
]

# --- Site Local Inside (SLI) Network (Used only if num_nics = 2) ---
# Subnet Resource IDs for the SLI (eth1) interface.
# NOTE: The number of items in this list MUST match 'num_nodes' if num_nics = 2.
sli_subnet_ids = [
  "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/sli-1",
  # "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/sli-2",
  # "/subscriptions/<SUB_ID>/resourceGroups/<RG>/providers/Microsoft.Network/virtualNetworks/<VNET>/subnets/sli-3"
]

# --- Public IP Assignment ---
# Configure how Public IPs are handled for the SLO interface.
public_ip_config = {
  create_public_ip       = true # Set to true to create and assign new Azure Public IPs
  existing_public_ip_ids = []   # Provide Resource IDs if create_public_ip = false
}

# --- Network Security Groups (NSGs) ---
# Configure NSGs for SLO and SLI interfaces.
security_group_config = {
  # Set to 'true' to create new, open NSGs. 'false' to use existing.
  create_slo_sg      = true
  create_sli_sg      = true

  # Provide NSG Resource ID if create_slo_sg = false
  existing_slo_sg_id = ""

  # Provide NSG Resource ID if create_sli_sg = false (and num_nics = 2)
  existing_sli_sg_id = ""

  #-----------------------------------------------------------------------------
  # NOTE ON SLI SECURITY GROUP:
  # If 'num_nics' is set to 1, the 'create_sli_sg' and 'existing_sli_sg_id'
  # settings are safely ignored.
  #-----------------------------------------------------------------------------
}

################################################################################
# 5. SSH KEY DETAILS
################################################################################

public_key_config = {
  create_new_keypair     = true    # Set to true to generate a new key pair locally
  existing_azure_ssh_key = "none"  # Name of existing Azure SSH Key if create_new = false
}
