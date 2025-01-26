##############################################################################################################################
# BLOCK 1 #  Create SMSV2 site object on XC
##############################################################################################################################
resource "volterra_securemesh_site_v2" "smsv2-site-object" {
  name      = var.cluster_name
  namespace = "system"
  block_all_services = true
  logs_streaming_disabled = true
 # Conditionally set HA based on num_nodes
  # Set HA based on num_nodes
  disable_ha = var.num_nodes == 1 ? true : false
  enable_ha  = var.num_nodes == 3 ? true : false

  re_select {
    geo_proximity = true
  }

  azure {
    not_managed {}
    }

  lifecycle {
    ignore_changes = [
    labels
    ]
  }
}

##############################################################################################################################
# BLOCK 2 #  Create site token on XC
##############################################################################################################################
resource "volterra_token" "smsv2-token" {
  name      = "${volterra_securemesh_site_v2.smsv2-site-object.name}-token"
  namespace = "system"
  type      = 1
  site_name = volterra_securemesh_site_v2.smsv2-site-object.name

  depends_on = [volterra_securemesh_site_v2.smsv2-site-object]
}


##############################################################################################################################
# BLOCK 3 # NETWORK SECURITY GROUP SLO
##############################################################################################################################

resource "azurerm_network_security_group" "slo_nsg" {
  count               = var.security_group_config.create_slo_sg ? 1 : 0
  name                = "${var.cluster_name}-slo-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-all-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-all-outbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge({
    Name = "${var.cluster_name}-slo-nsg"
  }, var.tags)
}

##############################################################################################################################
# BLOCK 4 # NETWORK SECURITY GROUP SLI
##############################################################################################################################
resource "azurerm_network_security_group" "sli_nsg" {
  count               = var.num_nics == 2 && var.security_group_config.create_sli_sg ? 1 : 0
  name                = "${var.cluster_name}-sli-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  security_rule {
    name                       = "allow-all-inbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "allow-all-outbound"
    priority                   = 101
    direction                  = "Outbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = merge({
    Name = "${var.cluster_name}-sli-nsg"
  }, var.tags)
}



##############################################################################################################################
# BLOCK 5 # SSH KEY
##############################################################################################################################
resource "null_resource" "generate_ssh_key" {
  count = var.public_key_config.create_new_keypair ? 1 : 0

  triggers = {
    private_key_path = "${path.module}/keys/${var.cluster_name}_key"
    public_key_path  = "${path.module}/keys/${var.cluster_name}_key.pub"
  }

  
  provisioner "local-exec" {
  command = "mkdir -p \"${path.module}/keys\" && ssh-keygen -t rsa -b 4096 -f \"${self.triggers.private_key_path}\" -q -N \"\""
  }

  

  provisioner "local-exec" {
    when    = destroy
    command = "rm -f \"${self.triggers.private_key_path}\" \"${self.triggers.public_key_path}\" || true"
  }
}

data "local_file" "public_key" {
  count     = var.public_key_config.create_new_keypair ? 1 : 0
  depends_on = [null_resource.generate_ssh_key]
  filename   = "${path.module}/keys/${var.cluster_name}_key.pub"
}

resource "azurerm_ssh_public_key" "ssh_key" {
  count               = var.public_key_config.create_new_keypair ? 1 : 0
  depends_on          = [null_resource.generate_ssh_key]
  name                = "${var.cluster_name}-public-key"
  location            = var.location
  resource_group_name = var.resource_group_name
  public_key          = data.local_file.public_key[0].content
}


# Fetch the existing public key content if needed
data "azurerm_ssh_public_key" "existing_ssh_key" {
  name                = var.public_key_config.existing_azure_ssh_key
  resource_group_name = var.resource_group_name
  count               = var.public_key_config.create_new_keypair ? 0 : 1
}
##############################################################################################################################
# BLOCK 6 # PUBLIC IP 
##############################################################################################################################
resource "azurerm_public_ip" "public_ips" {
  count               = var.public_ip_config.create_public_ip ? var.num_nodes : 0
  name                = "${var.cluster_name}-public-ip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = [var.az_name[count.index]]

  tags = var.tags
}


##############################################################################################################################
# BLOCK 7 # NETWORK INTERFACE
##############################################################################################################################

resource "azurerm_network_interface" "nics" {
  count               = var.num_nodes * var.num_nics
  name                = "${var.cluster_name}-${count.index % var.num_nics == 0 ? "slo" : "sli"}-nic${floor(count.index / var.num_nics) + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  ip_configuration {
    name                          = "internal"
    # Subnet Assignment (Select correct subnet from the list)
    subnet_id                     = count.index % var.num_nics == 0 ? var.slo_subnet_ids[floor(count.index / var.num_nics)] : var.sli_subnet_ids[floor(count.index / var.num_nics)]
    private_ip_address_allocation = "Dynamic"

    # Public IP Assignment
        # Public IP Assignment
public_ip_address_id = count.index % var.num_nics == 0 ? (var.public_ip_config.create_public_ip ? azurerm_public_ip.public_ips[floor(count.index / var.num_nics)].id : var.public_ip_config.existing_public_ip_ids[floor(count.index / var.num_nics)]) : null
  }

  

  tags = var.tags
  depends_on = [azurerm_network_security_group.slo_nsg,azurerm_network_security_group.sli_nsg]
}

##############################################################################################################################
# BLOCK 8 # Associate NSG with Network Interfaces 
##############################################################################################################################
# For SLO NSG associations
resource "azurerm_network_interface_security_group_association" "slo_nsg_associations" {
  for_each = { for idx, nic in azurerm_network_interface.nics : idx => nic if idx % var.num_nics == 0 }

  network_interface_id      = each.value.id
  network_security_group_id = var.security_group_config.create_slo_sg ? azurerm_network_security_group.slo_nsg[floor(each.key / var.num_nodes)].id : var.security_group_config.existing_slo_sg_id

  depends_on = [
    azurerm_network_security_group.slo_nsg,
    azurerm_network_interface.nics
  ]
}

# For SLI NSG associations
resource "azurerm_network_interface_security_group_association" "sli_nsg_associations" {
  for_each = { for idx, nic in azurerm_network_interface.nics : idx => nic if idx % var.num_nics != 0 }

  network_interface_id      = each.value.id
  network_security_group_id = var.security_group_config.create_sli_sg ? azurerm_network_security_group.sli_nsg[floor(each.key / var.num_nodes)].id : var.security_group_config.existing_sli_sg_id

  depends_on = [
    azurerm_network_security_group.sli_nsg,
    azurerm_network_interface.nics
  ]
}



##############################################################################################################################
# BLOCK 9 # VIRTUAL MACHINES
##############################################################################################################################

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.num_nodes
  name                = "${var.cluster_name}-node-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  admin_username      = "cloud-user"
  network_interface_ids = slice(
    azurerm_network_interface.nics[*].id,
    count.index * var.num_nics,
    (count.index + 1) * var.num_nics
  )
   size             = var.vm_size
   zone = var.az_name[count.index] 

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_disk {
    caching           = "ReadWrite"
    disk_size_gb      = var.os_disk.size_gb
    storage_account_type = var.os_disk.type
  }

   custom_data = base64encode(<<-EOF
    #cloud-config
    write_files:
    - path: /etc/vpm/user_data
      content: |
        token: ${volterra_token.smsv2-token.id}
      owner: root
      permissions: '0644'
  EOF
  )
   admin_ssh_key {
    username   = "cloud-user"
        public_key = var.public_key_config.create_new_keypair ? azurerm_ssh_public_key.ssh_key[0].public_key : data.azurerm_ssh_public_key.existing_ssh_key[0].public_key
}



   plan {
    name      = var.image.sku
    publisher = var.image.publisher
    product   = var.image.offer
  }

  
    
  depends_on = [volterra_token.smsv2-token]

  tags = var.tags
}


