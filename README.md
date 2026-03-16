# F5 XC SMSV2 Customer Edge (CE) for Azure

This Terraform project deploys F5 Distributed Cloud (XC) SMSV2 (Secure Mesh Site V2) Customer Edge (CE) nodes on Microsoft Azure. This code is updated as per the latest release of Nov 16 2025.

This is a **unified and flexible** configuration, mirroring the AWS architecture logic. This module allows you to select your desired topology by changing variables in the `terraform.tfvars` file.

This single codebase handles:
* **"Cluster" Model**: A standard 1-node or 3-node HA Cluster site within a single Resource Group.
* **"vSite" Model**: Deploys 1, 2, or 3 independent nodes (separate Site Objects) grouped into a single Virtual Site.
* **Public IP**: Option to create new Public IPs, use existing Azure Public IP Resource IDs, or assign no public IP (Private only).
* **NICs**: Supports both single-NIC (SLO only) and dual-NIC (SLO + SLI) deployments using Azure Network Interfaces.

## Table of Contents
* [Core Configuration Concepts](#core-configuration-concepts)
  * [Deployment Model: Cluster vs. vSite](#1-deployment-model-cluster-vs-vsite)
  * [Networking: Public IP vs. NAT Gateway](#2-networking-public-ip-vs-nat-gateway)
  * [Node & NIC Count](#3-node--nic-count)
* [Prerequisites](#prerequisites)
* [File Structure](#file-structure)
* [How to Deploy](#how-to-deploy)
* [How to Destroy](#how-to-destroy)
* [Deployment Outputs](#deployment-outputs)
* [Troubleshooting & FAQ](#troubleshooting--faq)

---

## Core Configuration Concepts

You control the entire deployment architecture using the variables in `terraform.tfvars`.

### 1. Deployment Model: Cluster vs. vSite

The `deployment_model` variable determines the F5 XC site topology on Azure.

* **`"cluster"`: (Standard Cluster Model)**
    * Creates **one** `volterra_securemesh_site_v2` resource in F5 XC.
    * If `num_nodes = 1`, it creates a single node.
    * If `num_nodes = 3`, it creates a 3-node HA cluster.
    * All nodes share a single registration token.
    * **Use this model** for standard production-grade HA sites.

* **`"vsite"`: (Virtual Site Model)**
    * Creates **one** `volterra_securemesh_site_v2` resource *per node*.
    * Creates a `volterra_virtual_site` resource to group them logically using a shared label.
    * Each node gets its own unique registration token.
    * **Use this model** for independent node management while maintaining a single logical grouping.

### 2. Networking: Public IP vs. NAT Gateway

The `public_ip_config` object controls how Azure Public IPs are assigned to the SLO (eth0) interface.

* **`create_public_ip = true`**: **(Default)**
    * Terraform creates a new Azure Public IP (Standard SKU) for each node and associates it with the SLO NIC.
    * Ideal for direct internet connectivity and Site-to-Site VPNs.

* **`create_public_ip = false` + `existing_public_ip_ids`**:
    * Terraform associates your provided Resource IDs to the NICs.
    * Use this if you have pre-reserved Static Public IPs in Azure.

* **`create_public_ip = false` + `existing_public_ip_ids = []`**: **(NAT / Private Model)**
    * No public IP is assigned to the NIC.
    * **Mandatory:** Your Azure Subnet **must** be associated with an **Azure NAT Gateway** or a Route Table (UDR) pointing to an NVA (Azure Firewall) so the node can reach the F5 XC Global Controller.

### 3. Node & NIC Count

* `num_nodes`: Number of Azure Virtual Machines to deploy.
    * Cluster model: `1` or `3`.
    * vSite model: `1`, `2`, or `3`.
* `num_nics`: Number of Azure Network Interfaces per VM.
    * `1`: SLO (eth0) only.
    * `2`: SLO (eth0) + SLI (eth1).

---

## Prerequisites

1. **Terraform** (v1.3.0 or newer).
2. **Azure CLI** authenticated with `az login` and the correct subscription set.
3. **F5 Distributed Cloud Account** and an **API Credential (`.p12` file)**.

---

## File Structure

* `main.tf`: Core logic for Azure (VM, NIC, NSG, PIP) and F5 XC (Site, Token, Virtual Site) resources.
* `variables.tf`: Input variable definitions and validation logic.
* `provider.tf`: Declarations for `azurerm` and `volterra` providers.
* `terraform.tfvars`: User-defined values for the deployment.
* `outputs.tf`: Formatted outputs for IPs and site names.
* `/keys`: (Generated) Directory containing your local SSH key pair.
* `README.md`: This file.

---

## SSH Key Management

This project handles SSH access based on your `public_key_config` setting:

1. **Automatic Generation (`create_new_keypair = true`):**
   * Terraform will create a subdirectory named `keys` in your project folder.
   * It will generate a private key (`<cluster_name>_key`) and a public key (`<cluster_name>_key.pub`) inside that folder.
   * **Security Note:** The private key is stored in plain text. Ensure the `keys/` folder is added to your `.gitignore` to prevent committing sensitive keys to version control.

2. **Manual Key (`create_new_keypair = false`):**
   * Terraform will look for an existing SSH Public Key resource already uploaded to Azure using the name provided in `existing_azure_ssh_key`.

---

## How to Deploy

1. **Clone the Repository**
    ```bash
    git clone <your-repo-url>
    cd azure-f5-xc-ce
    ```

2. **Edit `terraform.tfvars`**
    Fill in your Azure environment details:
    * **XC API:** `api_p12_file`, `api_url`.
    * **Cloud Info:** `location`, `resource_group_name`, `vnet_name`.
    * **Topology:** `deployment_model`, `num_nodes`, `num_nics`.
    * **Networking:** Provide the correct number of Subnet Resource IDs in `slo_subnet_ids` to match `num_nodes`.

3. **Initialize & Apply**
    ```bash
    terraform init
    terraform plan
    terraform apply
    ```

---

## How to Destroy

To tear down all resources created by this project, run the destroy command.

```bash
terraform destroy
```

## Deployment Outputs

After a successful `terraform apply`, this module provides structured outputs to verify your Azure infrastructure and F5 XC registration status.

### 1. Deployment Summary

To see a complete summary of all the resources you deployed, run:

```bash
terraform output deployment_summary
```
This will display a structured object containing:

* **Azure VM IDs**: Full Azure Resource Manager (ARM) paths for the created Virtual Machines.
* **Public & Private IPs**: Allocated addresses for the **SLO (eth0)** and **SLI (eth1)** interfaces.
* **F5 XC Site Names**: The site names as they appear in the F5 Distributed Cloud Console.
* **Virtual Site Name**: The logical group name (only displayed if the `vsite` model was used).

### Sample Output (VSITE Model):

```bash
deployment_summary = {
  "azure_location" = "germanywestcentral"
  "cluster_name"   = "azure-smsv2-site"
  "deployment_model" = "vsite"
  "f5_xc_site_names" = [
    "azure-smsv2-site-1",
    "azure-smsv2-site-2",
    "azure-smsv2-site-3"
  ]
  "f5_xc_virtual_site_name" = "azure-smsv2-site-vsite"
  "node_count" = 3
  "private_ips_slo" = [
    "10.1.0.4",
    "10.1.1.4",
    "10.1.2.4"
  ]
  "private_ips_sli" = [
    "10.2.0.4",
    "10.2.1.4",
    "10.2.2.4"
  ]
  "public_ips_slo" = [
    "20.120.x.x",
    "20.120.y.y",
    "20.120.z.z"
  ]
  "vm_ids" = [
    "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Compute/virtualMachines/node-1",
    "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Compute/virtualMachines/node-2",
    "/subscriptions/xxx/resourceGroups/xxx/providers/Microsoft.Compute/virtualMachines/node-3"
  ]
}
```
### Sample Output (VSITE Model):

```bash
deployment_summary = {
  "azure_location" = "germanywestcentral"
  "cluster_name"   = "azure-cluster-ha"
  "deployment_model" = "cluster"
  "f5_xc_site_names" = [
    "azure-cluster-ha"
  ]
  "f5_xc_virtual_site_name" = "N/A (Cluster Model)"
  "node_count" = 3
  "private_ips_slo" = ["10.1.0.4", "10.1.0.5", "10.1.0.6"]
  "public_ips_slo"  = ["20.x.x.1", "20.x.x.2", "20.x.x.3"]
  # ...
}
```

## Troubleshooting & FAQ

**Q: `terraform plan` fails with a "Invalid value" error from a `check` block.**
* **A:** This is by design. We use `check` blocks to validate your variable combinations *before* creating resources in Azure. Read the error message carefully.
    * **Example 1:** `Invalid SLO NSG config: ... 'existing_slo_sg_id' must be provided.`
        * **Fix:** You set `create_slo_sg = false`, but did not provide the Resource ID for your existing Security Group.
    * **Example 2:** `Invalid node count: For 'cluster' model, num_nodes must be 1 or 3.`
        * **Fix:** F5 XC HA Clusters in Azure require exactly 3 nodes. If you need 2 nodes, you must use `deployment_model = "vsite"`.

**Q: `terraform apply` fails with an error about `element()` or `count.index`.**
* **A:** This means your lists in `terraform.tfvars` (like `slo_subnet_ids` or `az_name`) do not have the same number of items as `num_nodes`.
* **Fix:** Ensure that the number of items in your subnet lists and availability zones *exactly* matches the `num_nodes` value.

**Q: My Azure VMs were created, but the site never comes "Online" in the F5 XC Console.**
* **A:** This indicates the CE node cannot reach the F5 XC Global Network. This is a **connectivity/egress problem**.
* **Fix:**
    1. **Check Public IP Configuration:**
        * If `create_public_ip = true`: Ensure your **SLO Network Security Group** allows outbound traffic on TCP port 443.
    2. **Check Private Networking (No Public IP):**
        * If you assigned no public IP, your **Azure Subnet must** have a route to the internet via an **Azure NAT Gateway** or an Azure Firewall/NVA. Without this, the node cannot "call home."
    3. **Verify via Serial Console:** * In the Azure Portal, go to the VM -> Help -> **Serial Console**. If you see "VPM is waiting for registration token," the software is running but can't talk to the internet.

**Q: `terraform plan` fails with an "Invalid cluster_name" error.**
* **A:** Your `cluster_name` does not meet the Azure/XC naming standards.
* **Fix:** Use only lowercase letters, numbers, and hyphens (`-`). It must start with a letter and cannot end with a hyphen.

**Q: Error: "The zonal deployment is not supported in this region".**
* **A:** You are deploying to an Azure region that doesn't support Availability Zones (e.g., `North Central US`).
* **Fix:** In your `terraform.tfvars`, you may need to adjust the `az_name` or, if the region is non-zonal, modify the `main.tf` to remove the `zone` requirement for that specific deployment.
