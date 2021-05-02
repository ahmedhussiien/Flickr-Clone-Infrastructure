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

variable "storage_account_name" {
  description = "The name of your Azure Storage Account."
  type        = string
}

variable "extra_tags" {
  description = "Extra tags associated with resources created."
  type        = map(string)
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  type        = string
}

##############################################################################
#
# * DNS config variables
#
##############################################################################
variable "domain_resource_group_name" {
  description = "The resource group in which the Dns Zone exists."
  type        = string
}

variable "dns_zone_name" {
  description = "The DNS Zone where the resource exists."
  type        = string
}

variable "dns_record_name" {
  description = "The subdomain linked to your public ip."
  type        = string
}

##############################################################################
#
# * Networking variables
#
##############################################################################
variable "address_space" {
  description = "The address space that is used by the virtual network. You can supply more than one address space. Changing this forces a new resource to be created."
  default     = "10.0.0.0/16"
}

variable "subnet_prefix" {
  description = "The address prefix to use for the subnet."
  default     = "10.0.10.0/24"
}

variable "source_network" {
  description = "Allow access from this network prefix. Defaults to '*'."
  default     = "*"
}

##############################################################################
#
# * Linux VM variables
#
##############################################################################
variable "vm_hostname" {
  description = "Virtual machine hostname. will be used in the VM name, and storage-related names."
  type        = string
}

variable "vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B1ls"
  type        = string
}

variable "image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
  type        = string
}

variable "image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
  type        = string
}

variable "image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "18.04-LTS"
  type        = string
}

variable "image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
  type        = string
}

variable "admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

variable "certbot_email" {
  description = "The email address used for certbot ssl notifications."
  type        = string
}
