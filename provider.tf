terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
    volterra = {
      source = "volterraedge/volterra"
      version = "0.11.42"
    }
  }
}


provider "volterra" {
  api_p12_file = var.api_p12_file
  url          = var.api_url
}

provider "azurerm" {
  features {}
}