
##############################################################################
#
# * Variables
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

##############################################################################
#
# * DNS records
#
##############################################################################

resource "azurerm_dns_a_record" "webservers" {
  name                = "@"
  zone_name           = var.dns_zone_name
  resource_group_name = var.domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.webserver.id
}

resource "azurerm_dns_a_record" "www_webservers" {
  name                = "www"
  zone_name           = var.dns_zone_name
  resource_group_name = var.domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.webserver.id
}
