
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

##############################################################################
#
# * Basic config variables
#
##############################################################################

variable "project_name" {
  description = "The name of your project."
  type        = string
}

variable "resource_group_name" {
  description = "The name of your Azure Resource Group."
  type        = string
}

variable "resource_group_location" {
  description = "The location of your Azure Resource Group."
  type        = string
}

variable "extra_tags" {
  description = "Extra tags associated with resources created."
  type        = map(string)
  default     = {}
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  type        = string
}

locals {
  environment       = "stage"
  webservers_domain = "${var.webservers_dns_record_name}.${var.webservers_dns_zone_name}"

  tags = merge({
    "project"     = var.project_name,
    "environment" = local.environment
  }, var.extra_tags)
}

##############################################################################
#
# * Resource group with a virtual network
#
##############################################################################

resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.resource_group_location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.tags
}
