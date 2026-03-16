################################################################################
# 0. INPUT VALIDATIONS
################################################################################

check "valid_node_count_for_model" {
  assert {
    condition = (
      (var.deployment_model == "cluster" && contains([1, 3], var.num_nodes)) ||
      (var.deployment_model == "vsite" && contains([1, 2, 3], var.num_nodes))
    )
    error_message = "Invalid node count: For 'cluster' model, num_nodes must be 1 or 3. For 'vsite' model, num_nodes can be 1, 2, or 3."
  }
}

check "valid_security_group_configuration" {
  assert {
    condition = (
      (var.security_group_config.create_slo_sg && length(var.security_group_config.existing_slo_sg_id) == 0) ||
      (!var.security_group_config.create_slo_sg && length(var.security_group_config.existing_slo_sg_id) > 0)
    )
    error_message = "Invalid SLO NSG config: If 'create_slo_sg' is true, 'existing_slo_sg_id' must be empty. If 'create_slo_sg' is false, 'existing_slo_sg_id' must be provided."
  }
}

################################################################################
# 1. F5 XC VIRTUAL SITE LABELS
################################################################################

resource "volterra_known_label_key" "smsv2-vsite_key" {
  count = var.deployment_model == "vsite" ? 1 : 0

  key         = "${var.cluster_name}-vsite"
  namespace   = "shared"
  description = "key used for v-site creation"
}

resource "volterra_known_label" "smsv2-vsite_label" {
  count = var.deployment_model == "vsite" ? 1 : 0

  key         = volterra_known_label_key.smsv2-vsite_key[0].key
  namespace   = "shared"
  value       = "true"
  description = "label used for v-site creation"
  depends_on  = [volterra_known_label_key.smsv2-vsite_key]
}

################################################################################
# 2. AZURE NETWORK SECURITY GROUPS
################################################################################

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

################################################################################
# 3. AZURE NETWORKING (Public IPs & NICs)
################################################################################

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

resource "azurerm_network_interface" "nics" {
  count               = var.num_nodes * var.num_nics
  name                = "${var.cluster_name}-${count.index % var.num_nics == 0 ? "slo" : "sli"}-nic${floor(count.index / var.num_nics) + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = count.index % var.num_nics == 0 ? var.slo_subnet_ids[floor(count.index / var.num_nics)] : var.sli_subnet_ids[floor(count.index / var.num_nics)]
    private_ip_address_allocation = "Dynamic"
    
    public_ip_address_id = count.index % var.num_nics == 0 && var.public_ip_config.create_public_ip ? azurerm_public_ip.public_ips[floor(count.index / var.num_nics)].id : null
  }

  tags = var.tags
  depends_on = [azurerm_network_security_group.slo_nsg, azurerm_network_security_group.sli_nsg]
}

resource "azurerm_network_interface_security_group_association" "slo_nsg_associations" {
  for_each = { for idx, nic in azurerm_network_interface.nics : idx => nic if idx % var.num_nics == 0 }

  network_interface_id      = each.value.id
  network_security_group_id = var.security_group_config.create_slo_sg ? azurerm_network_security_group.slo_nsg[0].id : var.security_group_config.existing_slo_sg_id

  depends_on = [azurerm_network_security_group.slo_nsg, azurerm_network_interface.nics]
}

resource "azurerm_network_interface_security_group_association" "sli_nsg_associations" {
  for_each = { for idx, nic in azurerm_network_interface.nics : idx => nic if idx % var.num_nics != 0 }

  network_interface_id      = each.value.id
  network_security_group_id = var.security_group_config.create_sli_sg ? azurerm_network_security_group.sli_nsg[0].id : var.security_group_config.existing_sli_sg_id

  depends_on = [azurerm_network_security_group.sli_nsg, azurerm_network_interface.nics]
}

################################################################################
# 4. AZURE SSH KEY MANAGEMENT
################################################################################

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
  count      = var.public_key_config.create_new_keypair ? 1 : 0
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

data "azurerm_ssh_public_key" "existing_ssh_key" {
  count               = var.public_key_config.create_new_keypair ? 0 : 1
  name                = var.public_key_config.existing_azure_ssh_key
  resource_group_name = var.resource_group_name
}

################################################################################
# 5. F5 XC SITE & TOKEN
################################################################################

resource "volterra_securemesh_site_v2" "smsv2-site-object" {
  count     = var.deployment_model == "vsite" ? var.num_nodes : 1
  name      = var.deployment_model == "vsite" ? "${var.cluster_name}-${count.index + 1}" : var.cluster_name
  namespace = "system"

  labels = var.deployment_model == "vsite" ? {
    (volterra_known_label.smsv2-vsite_label[0].key) = (volterra_known_label.smsv2-vsite_label[0].value)
  } : {}

  block_all_services      = true
  logs_streaming_disabled = true
  
  disable_ha = var.deployment_model == "vsite" || (var.deployment_model == "cluster" && var.num_nodes == 1)
  enable_ha  = var.deployment_model == "cluster" && var.num_nodes == 3

  azure {
    not_managed {
      dynamic "node_list" {
        for_each = var.deployment_model == "cluster" ? range(var.num_nodes) : [count.index]
        content {
          hostname = "${var.cluster_name}-node-${node_list.value + 1}"
          type     = "Control"

          dynamic "interface_list" {
            for_each = range(var.num_nics)
            content {
              name = interface_list.value == 0 ? "eth0" : "eth1"
              ethernet_interface {
                device = interface_list.value == 0 ? "eth0" : "eth1"
              }
              network_option {
                site_local_network        = interface_list.value == 0
                site_local_inside_network = interface_list.value == 1
              }
            }
          }
        }
      }
    }
  }

  lifecycle { ignore_changes = [labels] }
  depends_on = [volterra_known_label.smsv2-vsite_label]
}

resource "volterra_token" "smsv2-token" {
  count     = var.deployment_model == "vsite" ? var.num_nodes : 1
  name      = "${volterra_securemesh_site_v2.smsv2-site-object[count.index].name}-token"
  namespace = "system"
  type      = 1
  site_name = volterra_securemesh_site_v2.smsv2-site-object[count.index].name
  
  depends_on = [volterra_securemesh_site_v2.smsv2-site-object]
}

################################################################################
# 6. AZURE COMPUTE (Virtual Machines)
################################################################################

resource "azurerm_linux_virtual_machine" "vm" {
  count               = var.num_nodes
  name                = "${var.cluster_name}-node-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  admin_username      = "cloud-user"
  size                = var.vm_size
  zone                = var.az_name[count.index]

  network_interface_ids = slice(
    azurerm_network_interface.nics[*].id,
    count.index * var.num_nics,
    (count.index + 1) * var.num_nics
  )

  source_image_reference {
    publisher = var.image.publisher
    offer     = var.image.offer
    sku       = var.image.sku
    version   = var.image.version
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = var.os_disk.type
    disk_size_gb         = var.os_disk.size_gb
  }

  custom_data = base64encode(<<-EOF
    #cloud-config
    write_files:
    - path: /etc/vpm/user_data
      content: |
        token: ${var.deployment_model == "cluster" ? volterra_token.smsv2-token[0].id : volterra_token.smsv2-token[count.index].id}
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

  lifecycle {
    ignore_changes = [custom_data]
  }

  depends_on = [volterra_token.smsv2-token]
  tags       = var.tags
}

################################################################################
# 7. F5 XC VIRTUAL SITE
################################################################################

resource "volterra_virtual_site" "smsv2-vsite" {
  count     = var.deployment_model == "vsite" ? 1 : 0
  name      = "${var.cluster_name}-vsite"
  namespace = "shared"
  site_type = "CUSTOMER_EDGE"
  
  site_selector {
    expressions = ["${var.cluster_name}-vsite in (true)"]
  }

  depends_on = [volterra_known_label.smsv2-vsite_label]
}
