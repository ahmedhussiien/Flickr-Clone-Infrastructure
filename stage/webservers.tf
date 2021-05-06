
##############################################################################
#
# * Variables - Networking
#
##############################################################################

variable "webservers_ssh_source_network" {
  description = "Allow SSH access from this network prefix. Defaults to '*'."
  default     = "*"
}

variable "webservers_domain_resource_group_name" {
  description = "The resource group in which the Dns Zone exists."
  type        = string
}

variable "webservers_dns_zone_name" {
  description = "The DNS Zone where the resource exists."
  type        = string
}

variable "webservers_dns_record_name" {
  description = "The subdomain linked to your public ip."
  type        = string
}

##############################################################################
#
# * Variables - web servers
#
##############################################################################

variable "num_webservers" {
  description = "Number of web servers to create. Defaults to 1"
  type        = number
  default     = 1
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
# * Networking
#
##############################################################################

resource "azurerm_subnet" "webservers" {
  name                 = "${var.prefix}-webservers-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "azurerm_network_security_group" "webservers" {
  name                = "${var.prefix}-webservers-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "SSH"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.webservers_ssh_source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 301
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_public_ip.webservers_lb.ip_address
  }

  security_rule {
    name                       = "HTTP"
    priority                   = 302
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = azurerm_public_ip.webservers_lb.ip_address
  }
}

resource "azurerm_subnet_network_security_group_association" "webservers" {
  subnet_id                 = azurerm_subnet.webservers.id
  network_security_group_id = azurerm_network_security_group.webservers.id
}

##############################################################################
#
# * Load balancer
#
##############################################################################

resource "azurerm_public_ip" "webservers_lb" {
  name                = "${var.prefix}-webservers-lb-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_lb" "this" {
  name                = "${var.prefix}-webservers-lb"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  frontend_ip_configuration {
    name                 = "${var.prefix}-webservers-lb-frontend-ipconfig"
    public_ip_address_id = azurerm_public_ip.webservers_lb.id
  }
}

resource "azurerm_lb_backend_address_pool" "webservers" {
  name                = "${var.prefix}-webservers-lb-backend-pool"
  resource_group_name = azurerm_resource_group.this.name
  loadbalancer_id     = azurerm_lb.this.id
}

##############################################################################
#
# * Virtual machines networking
#
##############################################################################

resource "azurerm_public_ip" "webservers" {
  count               = var.num_webservers
  name                = "${var.prefix}-webserver${count.index}-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "webservers" {
  count               = var.num_webservers
  name                = "${var.prefix}-webserver${count.index}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-webserver${count.index}-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.webservers.id
    public_ip_address_id          = element(azurerm_public_ip.webservers.*.id, count.index)
  }
}

resource "azurerm_network_interface_backend_address_pool_association" "webservers" {
  count                   = var.num_webservers
  network_interface_id    = element(azurerm_network_interface.webservers.*.id, count.index)
  ip_configuration_name   = "${var.prefix}-webserver${count.index}-ipconfig"
  backend_address_pool_id = azurerm_lb_backend_address_pool.webservers.id
}

##############################################################################
#
# * Ubuntu Linux VMs
#
##############################################################################

resource "azurerm_linux_virtual_machine" "webservers" {
  count               = var.num_webservers
  name                = "${var.prefix}-webserver${count.index}"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.vm_size
  tags                = local.tags

  network_interface_ids = [element(azurerm_network_interface.webservers.*.id, count.index)]

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    name                 = "${var.prefix}-webserver${count.index}-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  computer_name  = var.prefix
  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("keys/webservers.pem")
  }

  provisioner "file" {
    source      = "scripts"
    destination = "/home/${var.admin_username}"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("keys/webservers.key")
      host        = element(azurerm_public_ip.webservers.*.ip_address, count.index)
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_username}/scripts/*",
      "sudo /home/${var.admin_username}/scripts/install-docker.sh",
      "sudo /home/${var.admin_username}/scripts/install-certbot.sh",
      "sudo /home/${var.admin_username}/scripts/issue-cert.sh ${local.webservers_domain} ${var.certbot_email}",
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("keys/webservers.key")
      host        = element(azurerm_public_ip.webservers.*.ip_address, count.index)
    }
  }
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_action_group" "webservers" {
  name                = "${var.prefix}-webservers-actiongroup"
  short_name          = var.prefix
  resource_group_name = azurerm_resource_group.this.name

  email_receiver {
    name          = var.alert_mailbox_name
    email_address = var.alert_mailbox
  }
}

resource "azurerm_monitor_metric_alert" "webservers_cpu" {
  name                = "${var.prefix}-webservers-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = azurerm_linux_virtual_machine.webservers[*].id
  description         = "Action will be triggered when Transactions count is greater than ${var.vm_cpu_threshold}."

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.vm_cpu_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.webservers.id
  }
}

##############################################################################
#
# * Create DNS records
#
##############################################################################

resource "azurerm_dns_a_record" "this" {
  name                = var.webservers_dns_record_name
  zone_name           = var.webservers_dns_zone_name
  resource_group_name = var.webservers_domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.webservers_lb.id
}

resource "azurerm_dns_a_record" "www_this" {
  name                = "www.${var.webservers_dns_record_name}"
  zone_name           = var.webservers_dns_zone_name
  resource_group_name = var.webservers_domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.webservers_lb.id
}

##############################################################################
#
# * Outputs
#
##############################################################################

output "webservers_load_balancer_ip" {
  value = azurerm_public_ip.webservers_lb.ip_address
}

output "webservers_public_ips" {
  value = azurerm_public_ip.webservers[*].id
}
