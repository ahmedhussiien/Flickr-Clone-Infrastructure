variable "prefix" {
  description = "This prefix will be included in the name of some resources."
  type        = string
  default     = "env"
}

variable "storage_account_name" {
  description = "The name of the storage account name."
  type        = string
}
