##############################################################################
#
# * Variables - Monitoring alerts
#
##############################################################################

variable "alert_mailbox" {
  description = "The email address used for monitoring alerts notifications."
  type        = string
}

variable "alert_mailbox_name" {
  description = "The name of the mail box used for monitoring alerts notifications."
  default     = "sendtodevops"
  type        = string
}

variable "vm_cpu_threshold" {
  description = "The threshold at which an alert email will be send."
  default     = 70
  type        = number
}


##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_action_group" "devops" {
  name                = "${var.prefix}-actiongroup"
  short_name          = var.prefix
  resource_group_name = azurerm_resource_group.this.name

  email_receiver {
    name          = var.alert_mailbox_name
    email_address = var.alert_mailbox
  }
}
