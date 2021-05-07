
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
  environment = "stage"
  # webservers_domain = "${var.webservers_dns_record_name}.${var.webservers_dns_zone_name}"

  tags = merge({
    "project"     = var.project_name,
    "environment" = local.environment
  }, var.extra_tags)
}

##############################################################################
#
# * Subnets prefixes
#
##############################################################################

variable "webservers_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.1.0/24"
}

variable "mongo_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.2.0/24"
}

variable "redis_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.3.0/24"
}

variable "jenkins_subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.4.0/24"
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

##############################################################################
#
# * Subnets
#
##############################################################################

resource "azurerm_subnet" "jenkins" {
  name                 = "${var.prefix}-jenkins-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [var.jenkins_subnet_prefix]
}

resource "azurerm_subnet" "webservers" {
  name                 = "${var.prefix}-webservers-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [var.webservers_subnet_prefix]
}

resource "azurerm_subnet" "mongo" {
  name                 = "${var.prefix}-mongo-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [var.mongo_subnet_prefix]
}

resource "azurerm_subnet" "redis" {
  name                 = "${var.prefix}-redis-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [var.redis_subnet_prefix]
}
