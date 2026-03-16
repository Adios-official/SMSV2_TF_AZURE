################################################################################
# 1. F5 DISTRIBUTED CLOUD (XC) API CREDENTIALS
################################################################################

variable "api_p12_file" {
  description = "Path to the F5 XC API credential file (PKCS12)"
  type        = string
}

variable "api_url" {
  description = "F5 XC API URL (e.g., 'https://<tenant>.console.ves.volterra.io/api')"
  type        = string
}

################################################################################
# 2. DEPLOYMENT MODEL & SITE VARIABLES
################################################################################

variable "deployment_model" {
  description = "The logical deployment model: 'cluster' (standard HA site) or 'vsite' (multiple independent sites grouped by a virtual_site)."
  type        = string
  default     = "cluster"

  validation {
    condition     = contains(["cluster", "vsite"], var.deployment_model)
    error_message = "The deployment_model must be either 'cluster' or 'vsite'."
  }
}

variable "cluster_name" {
  description = "Base name for the F5 XC site(s) and Azure resources. Must be a valid DNS-1035 label."
  type        = string

  validation {
    # This regex enforces DNS-1035 label requirements
    condition     = can(regex("^[a-z]([a-z0-9-]*[a-z0-9])?$", var.cluster_name))
    error_message = "Invalid cluster_name: Must consist of lower case alphanumeric characters or '-', start with a letter, and end with an alphanumeric character."
  }
}

variable "num_nodes" {
  description = "Number of CE nodes to create. 'cluster' model supports 1 or 3. 'vsite' model supports 1, 2, or 3."
  type        = number
  # Validation for this is handled by a 'check' block in main.tf
}

variable "num_nics" {
  description = "Number of network interfaces per node: 1 (SLO only) or 2 (SLO + SLI)."
  type        = number

  validation {
    condition     = contains([1, 2], var.num_nics)
    error_message = "The number of NICs must be either 1 or 2."
  }
}

################################################################################
# 3. AZURE COMPUTE & IMAGE VARIABLES
################################################################################

variable "location" {
  description = "Azure region to deploy resources (e.g., 'Germany West Central')"
  type        = string
}

variable "vm_size" {
  description = "Azure VM size for the CE nodes (e.g., 'Standard_DS3_v2')"
  type        = string
}

variable "image" {
  description = "Azure Image reference details for the F5 XC CE nodes"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
}

variable "os_disk" {
  description = "Azure OS Disk configuration"
  type = object({
    size_gb = number
    type    = string
  })
}

variable "az_name" {
  description = "List of Azure Availability Zones. The number of zones must match 'var.num_nodes'."
  type        = list(string)
}

variable "tags" {
  description = "A map of custom Azure tags to apply to all created resources"
  type        = map(string)
  default     = {}
}

################################################################################
# 4. AZURE NETWORKING & SECURITY VARIABLES
################################################################################

variable "resource_group_name" {
  description = "Name of the Azure Resource Group"
  type        = string
}

variable "vnet_name" {
  description = "Name of the Azure Virtual Network (VNet)"
  type        = string
}

variable "slo_subnet_ids" {
  description = "List of Subnet Resource IDs for the SLO (eth0) interface. Must match 'var.num_nodes'."
  type        = list(string)
}

variable "sli_subnet_ids" {
  description = "List of Subnet Resource IDs for the SLI (eth1) interface. Only used if 'num_nics = 2'."
  type        = list(string)
  default     = []
}

variable "public_ip_config" {
  description = "Configuration for Azure Public IPs."
  type = object({
    create_public_ip       = bool
    existing_public_ip_ids = list(string)
  })
}

variable "security_group_config" {
  description = "Configuration for SLO and SLI Network Security Groups (NSGs)."
  type = object({
    create_slo_sg      = bool
    create_sli_sg      = bool
    existing_slo_sg_id = string
    existing_sli_sg_id = string
  })
}

################################################################################
# 5. AZURE SSH KEY VARIABLES
################################################################################

variable "public_key_config" {
  description = "Configuration for the SSH key pair used for VM access."
  type = object({
    create_new_keypair     = bool
    existing_azure_ssh_key = string
  })
}
