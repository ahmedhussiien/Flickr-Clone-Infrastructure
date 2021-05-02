locals {
  environment = "stage"

  tags = merge({
    "project"     = var.project_name,
    "environment" = local.environment
  }, var.extra_tags)
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }

  backend "azurerm" {
    key = "stage/terraform.tfstate"
  }
}

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.resource_group_location
}

resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}
