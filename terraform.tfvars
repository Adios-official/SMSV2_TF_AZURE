##############################################################################################################################
# BLOCK 1 #  BASIC AZURE VARIABLES
##############################################################################################################################
# Azure Region
# CHANGE THIS
location = "Germany West Central"

# Resource Group Information
# CHANGE THIS
resource_group_name = "xxxxxxxxx"

#Virtual Network Details
# CHANGE THIS
vnet_name = "xxxxxxxxx"

##############################################################################################################################
# BLOCK 2 #  BASIC VARIABLES FOR VIRTUAL MACHINES
# AZURE Instance Information - Resources required per node: Minimum 4 vCPUs, 14 GB RAM, and 80 GB disk storage
# CHANGE THESE VALUES AS PER YOUR USE-CASE
##############################################################################################################################

cluster_name = "azure-smsv2-3node-2nic"   # Name for the customer Edge ( Each node will take this name followed by suffix like node-1, node-2 etc. )
num_nodes    = 3                            # Choose if you need a Single Node CE or an HA CE with 3 Nodes
num_nics     = 2                            # Use 1 for single NIC or 2 for dual NIC. 
vm_size      = "Standard_DS3_v2"            # SMALL :Standard_DS3_v2, Medium :Standard_DS4_v2, Large:Standard_DS5_v2

# Image details for the VMs
# Confirm latest image details with the F5 Engineer
image = {                                   # Azure Image reference
  publisher = "f5-networks"
  offer     = "f5xc_customer_edge"
  sku       = "f5xccebyol"
  version   = "2024.40.2"
}

#storage variables
os_disk = {
  size_gb    = 80                          # Disk size in GB. 80 GB is minimum. (default size depends on the AMI, but you can override it).
  type       = "Standard_LRS"              # ["Premium_LRS" "Standard_LRS" "StandardSSD_LRS" "StandardSSD_ZRS" "Premium_ZRS"]
}
tags = {                                    # Tags you would like to add to the nodes in the CE cluster. 
  Environment = "Development"
  Owner       = "your.email@example.com"
}

##############################################################################################################################
# BLOCK 3 # PUBLIC IP ASSIGNMENT VARIABLES
##############################################################################################################################

# Public IP configuration (either create new Public IPs or use existing ones)
# These are the Azure Public IPs that would be then assigned to the SLO interface 
# If you don't want IPs to be created by the code, you can use your existing IPs by choosing create_public_ip as false and providing existing_public_ip_ids
# FORMAT (existing_public_ip_ids): /subscriptions/<Subscription ID>/resourceGroups/<Resource Group Name>/providers/Microsoft.Network/publicIPAddresses/<Public IP Address Name>
# CHANGE THIS AS PER NEED
public_ip_config = {
  create_public_ip = true             # Set to true to create and assign public IPs to VMs
  existing_public_ip_ids = []         # Leave empty if create_public_ip = true  
            
}

##############################################################################################################################
# BLOCK 4 # SECURITY GROUP DETAILS
##############################################################################################################################
# Security group configuration (either create new Security groups or use existing ones)
# When you choose to create new Security groups , the code creates a security group which has an allow all policy.
# If you want to add further rules, you can add in main.tf or you add additional rules to the security group after the site provisioning is complete.
#FORMAT (existing_slo_sg_id/existing_sli_sg_id) : /subscriptions/<Subscription ID>/resourceGroups/<Resource Group Name>/providers/Microsoft.Network/networkSecurityGroups/<NSG Name>
# CHANGE THIS AS PER NEED

security_group_config = {
  create_slo_sg     = false     # Set to true to create NSG for attaching to SLO
  create_sli_sg     = false     # Set to true to create NSG for attaching to SLI
  existing_slo_sg_id = "/subscriptions/xxxxxxx/resourceGroups/xxxxxxx/providers/Microsoft.Network/networkSecurityGroups/xxxxxxx"    # Leave empty if create_slo_sg is true, otherwise provide existing Security group IDs for SLO interface
  existing_sli_sg_id = "/subscriptions/xxxxxxx/resourceGroups/xxxxxxx/providers/Microsoft.Network/networkSecurityGroups/xxxxxxx"      # Leave empty if create_sli_sg is true, otherwise provide existing Security group  IDs for SLI interface
}


##############################################################################################################################
# BLOCK 5 #  NETWORKING AND NETWORK INTERFACES FOR NODES
# 5.1 SLO CONFIG 
# Provide distinct SLO subnet values for each node if 3 nodes
##############################################################################################################################

# Subnet IDs (ensure these match the number of nodes if num_nodes = 3)
# Add your Subnet IDs here for SLO, 1 for each node in case of 3 nodes. For 1 node just 1 value is enough in the list.
# FORMAT(slo_subnet_ids): /subscriptions/<Subscription ID>/resourceGroups/<Resource Group Name>/providers/Microsoft.Network/virtualNetworks/<VNet Name>/subnets/<Subnet Name>
# CHANGE THIS
slo_subnet_ids = [
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx",
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx",
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx"
]

##############################################################################################################################
# BLOCK 5 #  NETWORKING AND NETWORK INTERFACES FOR NODES
# 5.2 SLI CONFIG 
# VALUES ARE ONLY CONSUMED IF YOU NEED DUAL NIC AND YOU HAVE GIVEN num_nics = 2
# Provide distinct SLI subnet values for each node if 3 nodes
##############################################################################################################################

# Subnet IDs (ensure these match the number of nodes if num_nodes = 3)
# Add your Subnetwork/Subnet name here for SLI, 1 for each node in case of 3 nodes. For 1 node just 1 value is enough in the list.
# FORMAT(sli_subnet_ids): /subscriptions/<Subscription ID>/resourceGroups/<Resource Group Name>/providers/Microsoft.Network/virtualNetworks/<VNet Name>/subnets/<Subnet Name>
# CHANGE THIS
sli_subnet_ids = [
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx",
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx",
  "/subscriptions/xxxxxxx/resourceGroups/xxxxxxxxx/providers/Microsoft.Network/virtualNetworks/xxxxxxx/subnets/xxxxxxx"
]

##############################################################################################################################
# BLOCK 6 # SSH KEY DETAILS
# SSH key if needs to be freshly created or use an existing one on azure
# When you choose to create new key pair , the code creates a key pair which is placed in a folder "keys" in present working directory
##############################################################################################################################
public_key_config = {
  create_new_keypair    = false      # Set to true to create new key pair locally and use that in azure. Note : Via terraform you cannot generate private key in azure as in UI.
  existing_azure_ssh_key = "xxxxxx"  # Leave empty if create_new_keypair = true. Only the name of the key that exists in azure. No need of full resource ID as in other resources.
}

##############################################################################################################################
# BLOCK 7 # AVAILABILITY ZONE DETAILS
# Provide distinct Availability zone values for each node if 3 nodes
##############################################################################################################################
# Availability Zones (ensure these match the number of nodes if num_nodes = 3)
# CHANGE THIS

az_name = ["1","2","3"]  #Add 3 zones if num_noes is 3. Azure follows AZ naming in a format 1 or 2 or 3, not like other clouds.

##############################################################################################################################
# BLOCK 8 # API CREDENTIAL DETAILS , TENANT DETAILS FROM DISTRIBUTED CLOUD
##############################################################################################################################

# These are arguments to supply your API credentials for interacting with the XC Tenant
# CHANGE THIS

api_p12_file = "xxxxxxx.console.ves.volterra.io.api-creds.p12"
api_url      = "https://xxxxxxx.console.ves.volterra.io/api"

