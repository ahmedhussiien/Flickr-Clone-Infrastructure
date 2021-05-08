
##############################################################################
#
# * Variables - Networking
#
##############################################################################

variable "redis_ssh_source_network" {
  description = "Allow SSH access from this network prefix. Defaults to '*'."
  default     = "*"
}

##############################################################################
#
# * Variables - Redis server
#
##############################################################################

variable "redis_vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B1ms"
  type        = string
}

variable "redis_image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
  type        = string
}

variable "redis_image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
  type        = string
}

variable "redis_image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "18.04-LTS"
  type        = string
}

variable "redis_image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
  type        = string
}

variable "redis_server_admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

##############################################################################
#
# * Variables - Redis database
#
##############################################################################

variable "redis_admin_password" {
  description = "Redis Administrator password"
  type        = string
}

##############################################################################
#
# * Networking
#
##############################################################################

resource "azurerm_network_security_group" "redis" {
  name                = "${var.prefix}-redis-nsg"
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
    source_address_prefix      = var.redis_ssh_source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "REDIS"
    priority                   = 305
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "6379"
    source_address_prefix      = var.webservers_subnet_prefix
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "redis" {
  subnet_id                 = azurerm_subnet.redis.id
  network_security_group_id = azurerm_network_security_group.redis.id
}

##############################################################################
#
# * Virtual machines networking
#
##############################################################################

resource "azurerm_public_ip" "redis" {
  name                = "${var.prefix}-redis-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "redis" {
  name                = "${var.prefix}-redis-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-redis-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.redis.id
    public_ip_address_id          = azurerm_public_ip.redis.id
  }
}

##############################################################################
#
# * Ubuntu Linux VMs
#
##############################################################################

resource "azurerm_linux_virtual_machine" "redis" {
  name                = "${var.prefix}-redis"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.redis_vm_size
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.redis.id, ]

  source_image_reference {
    publisher = var.redis_image_publisher
    offer     = var.redis_image_offer
    sku       = var.redis_image_sku
    version   = var.redis_image_version
  }

  os_disk {
    name                 = "${var.prefix}-redis-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  computer_name  = "${var.prefix}-redis"
  admin_username = var.redis_server_admin_username

  admin_ssh_key {
    username   = var.redis_server_admin_username
    public_key = file("keys/redis.pem")
  }

  provisioner "file" {
    source      = "scripts/install-redis.sh"
    destination = "/home/${var.redis_server_admin_username}/install-redis.sh"

    connection {
      type        = "ssh"
      user        = var.redis_server_admin_username
      private_key = file("keys/redis.key")
      host        = azurerm_public_ip.redis.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.redis_server_admin_username}/install-redis.sh",
      "sudo /home/${var.redis_server_admin_username}/install-redis.sh ${var.redis_admin_password}",
    ]

    connection {
      type        = "ssh"
      user        = var.redis_server_admin_username
      private_key = file("keys/redis.key")
      host        = azurerm_public_ip.redis.ip_address
    }
  }
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_metric_alert" "redis_cpu" {
  name                = "${var.prefix}-redis-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name

  scopes = [azurerm_linux_virtual_machine.redis.id]

  description = "Action will be triggered when CPU utilization is greater than ${var.vm_cpu_threshold}."

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.vm_cpu_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.devops.id
  }
}

##############################################################################
#
# * Outputs
#
##############################################################################

output "redis_public_ip" {
  value = azurerm_public_ip.redis.ip_address
}

output "redis_host" {
  value = azurerm_network_interface.redis.private_ip_address
}
