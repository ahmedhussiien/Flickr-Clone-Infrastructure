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

variable "state_container_name" {
  description = "The name of your Azure Storage Container that contains tfstate files."
  type        = string
}

variable "extra_tags" {
  description = "Extra tags associated with resources created."
  type        = map(string)
}

variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  type        = string
  default     = "env"
}
