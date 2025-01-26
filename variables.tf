##############################################################################################################################
# BLOCK 1 #  AZURE BASIC VARIABLES
##############################################################################################################################

variable "location" {
  description = "Azure region to deploy the resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Azure VNET"
  type        = string
}

variable "az_name" {
  description = "List of availability zone names for each node"
  type        = list(string)
  default     = ["1","2","3"]  # Example for 3 zones, adjust as per your region's available zones
}

##############################################################################################################################
# BLOCK 2 #  BASIC VARIABLES FOR VIRTUAL MACHINES
##############################################################################################################################

variable "cluster_name" {
  description = "Base name for the virtual machines"
  type        = string
}

variable "vm_size" {
  description = "Size of the virtual machines"
  type        = string
}

variable "num_nodes" {
  description = "Number of nodes to create (1 or 3)"
  type        = number
  validation {
    condition     = contains([1, 3], var.num_nodes)
    error_message = "The number of nodes must be either 1 or 3. The value '2' or any other value is not supported."
  }
}

variable "num_nics" {
  description = "Number of NICs per virtual machine (1 for single NIC, 2 for dual NIC)"
  type        = number
  validation {
    condition     = contains([1, 2], var.num_nics)
    error_message = "The number of Interfaces must be either 1 or 2. Any other value is not supported in this code."
  }
}

variable "image" {
  description = "VM image details (publisher, offer, sku, version)"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "tags" {
  description = "Tags for Azure resources"
  type        = map(string)
}

##############################################################################################################################
# BLOCK 3 #  NETWORKING AND PUBLIC IP VARIABLES
##############################################################################################################################


variable "sli_subnet_ids" {
  description = "List of subnet IDs for the virtual network (1 for single node, 3 for HA setup)"
  type        = list(string)
}

variable "slo_subnet_ids" {
  description = "List of subnet IDs for the virtual network (1 for single node, 3 for HA setup)"
  type        = list(string)
}

variable "public_ip_config" {
  description = "Public IP configuration for the VMs"
  type = object({
    create_public_ip = bool
    existing_public_ip_ids = list(string)
  })
  default = {
    create_public_ip = true
    existing_public_ip_ids = []
  }
  validation {
    condition = (
      var.public_ip_config.create_public_ip && length(var.public_ip_config.existing_public_ip_ids) == 0 ||
      !var.public_ip_config.create_public_ip && length(var.public_ip_config.existing_public_ip_ids) != 0
    )
    error_message = "Validation failed: If 'create_public_ip' is true, 'existing_public_ip_ids' should be empty. If false, it must match 'num_nodes'."
  }
}

##############################################################################################################################
# BLOCK 4 # SECURITY GROUP VARIABLES
##############################################################################################################################

# Security Group Configuration as an object
variable "security_group_config" {
  description = <<EOT
Configuration for Security Groups:
- create_slo_sg: Boolean to indicate whether to create a new SLO security group.
- create_sli_sg: Boolean to indicate whether to create a new SLI security group (only if num_nics == 2).
- existing_slo_sg_id: Existing security group ID for SLO (required if create_slo_sg is false).
- existing_sli_sg_id: Existing security group ID for SLI (required if create_sli_sg is false).
EOT
  type = object({
    create_slo_sg     = bool
    create_sli_sg     = bool
    existing_slo_sg_id = string
    existing_sli_sg_id = string
  })

  # Combined validation for both SLO and SLI security groups
# Combined validation for both SLO and SLI security groups
validation {
  condition = (
    # SLO security group validation
    (var.security_group_config.create_slo_sg && length(var.security_group_config.existing_slo_sg_id) == 0) || 
    (var.security_group_config.create_slo_sg == false && length(var.security_group_config.existing_slo_sg_id) > 0)
  ) && (
    # SLI security group validation 
      (var.security_group_config.create_sli_sg && length(var.security_group_config.existing_sli_sg_id) == 0) ||
      (var.security_group_config.create_sli_sg == false && length(var.security_group_config.existing_sli_sg_id) > 0)   
  )
    error_message = <<EOT
Invalid security group configuration. Please ensure that:
  - If create_slo_sg is false, existing_slo_sg_id must be provided.
  - If create_slo_sg is true, existing_slo_sg_id must be empty.
  - If create_sli_sg is false, existing_sli_sg_id must be provided.
  - If create_sli_sg is true, existing_sli_sg_id must be empty.
EOT
 }
}
##############################################################################################################################
# BLOCK 5 # STORAGE VARIABLES
##############################################################################################################################

variable "os_disk" {
  description = "OS Disk configuration for the VMs"
  type = object({
    size_gb   = number
    type      = string
  })
}

##############################################################################################################################
# BLOCK 6 # SSH KEY VARIABLES
##############################################################################################################################
variable "public_key_config" {
  description = "Configuration for SSH public key management, including options to create a new key pair or use an existing Azure SSH public key."
  type = object({
    create_new_keypair      = bool
    existing_azure_ssh_key = string
  })
  default = {
    create_new_keypair      = true
    existing_azure_ssh_key = ""
  }
}


##############################################################################################################################
# BLOCK 7 # AVAILABILITY ZONE DETAILS , TENANT DETAILS FROM DISTRIBUTED CLOUD
##############################################################################################################################

variable "api_p12_file" {
  description = "Path to the Volterra API Key"
  type        = string
}

variable "api_url" {
  description = "Volterra API URL"
  type        = string
}

