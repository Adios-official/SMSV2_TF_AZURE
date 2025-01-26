# Customer Edge (CE) with Public IP Assignment (Usable for All Normal Use Cases)

## Overview

This Terraform project deploys a cluster of Azure virtual machines (VMs) integrated with Volterra using dual NIC or single NIC configurations. It includes options for high availability (HA) with 3 nodes or a single-node setup.

---

## Prerequisites

Before using this Terraform project, ensure you have the following:

- **Terraform CLI** installed on your machine.
- An **Azure account** with appropriate permissions to create resources.
- API credentials (P12 file and URL) for **Volterra**.
- Access to existing **subnets** and **security groups** in Azure (if not creating them).
- SSH public key for VM authentication (optional).

---

## File Structure

```
project-directory/
├── main.tf
├── variables.tf
├── terraform.tfvars
├── providers.tf
```

---

## Configuration Steps

### 1. Clone the Repository

```bash
git clone <repository_url>
cd <repository_name>
```

### 2. Update Variables

#### Modify `terraform.tfvars`
Update the values in `terraform.tfvars` to match your deployment needs. Here are some key variables to configure:

- **Azure Variables:**
  ```hcl
  location             = "<Azure Region>"
  resource_group_name = "<Resource Group Name>"
  vnet_name           = "<Virtual Network Name>"
  ```

- **Cluster Configuration:**
  ```hcl
  cluster_name = "<Cluster Name>"
  num_nodes    = 3  # Choose 1 or 3
  num_nics     = 2  # Choose 1 or 2
  vm_size      = "Standard_DS3_v2"
  ```

- **Image Details:**
  ```hcl
  image = {
    publisher = "f5-networks"
    offer     = "f5xc_customer_edge"
    sku       = "f5xccebyol"
    version   = "2024.40.2"
  }
  ```

- **Networking:**
  ```hcl
  slo_subnet_ids = [
    "<Subnet ID 1>",
    "<Subnet ID 2>",
    "<Subnet ID 3>"
  ]

  sli_subnet_ids = [
    "<Subnet ID 1>",
    "<Subnet ID 2>",
    "<Subnet ID 3>"
  ]
  ```

- **Public IP Configuration:**
  ```hcl
  public_ip_config = {
    create_public_ip     = true
    existing_public_ip_ids = []
  }
  ```

- **Security Group Configuration:**
  ```hcl
  security_group_config = {
    create_slo_sg      = false
    existing_slo_sg_id = "<SLO Security Group ID>"
    create_sli_sg      = false
    existing_sli_sg_id = "<SLI Security Group ID>"
  }
  ```

### 3. Initialize Terraform

Run the following command to initialize Terraform and download required providers:

```bash
terraform init
```

### 4. Plan the Deployment

Verify the configuration by running:

```bash
terraform plan
```

This command shows the resources Terraform will create.

### 5. Deploy the Resources

Apply the configuration to create resources in Azure:

```bash
terraform apply
```

Type `yes` to confirm the deployment.

---

## Key Features

- **Dynamic NICs:** Option to configure single or dual NIC for VMs.
- **High Availability:** Choose between single-node or 3-node HA configurations.
- **Flexible Networking:** Assign custom subnets for SLO and SLI.
- **Custom Security Groups:** Use existing security groups or create new ones.
- **Public IPs:** Option to create or reuse public IPs for SLO interfaces.
- **SSH Key Management:** Option to create a new key pair or use an existing Azure SSH key.

---

## Validation Rules

- **Number of Nodes:**
  - Allowed values: `1` or `3`.
- **Number of NICs:**
  - Allowed values: `1` or `2`.
- **Public IP Configuration:**
  - If `create_public_ip` is true, `existing_public_ip_ids` must be empty.
  - If `create_public_ip` is false, provide existing public IP IDs matching `num_nodes`.
- **Security Groups:**
  - If `create_slo_sg` or `create_sli_sg` is false, provide existing security group IDs.

---

## Troubleshooting

### Common Issues

1. **Validation Errors:**
   Ensure variables in `terraform.tfvars` adhere to validation rules.

2. **Insufficient Permissions:**
   Verify your Azure account has permissions to create resources.

3. **API Credential Issues:**
   Ensure the `api_p12_file` and `api_url` are correctly specified.

### Debugging Tips

- Use the `terraform validate` command to check for syntax errors.
- Review the Terraform logs by setting the `TF_LOG` environment variable:
  ```bash
  export TF_LOG=DEBUG
  ```

---

## Cleanup

To destroy all resources created by this project, run:

```bash
terraform destroy
```

Type `yes` to confirm the deletion.

---

---

## Support

For issues or questions, contact your system administrator or the support team.
