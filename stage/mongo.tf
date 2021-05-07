
##############################################################################
#
# * Variables - Networking
#
##############################################################################

variable "mongo_ssh_source_network" {
  description = "Allow SSH access from this network prefix. Defaults to '*'."
  default     = "*"
}

##############################################################################
#
# * Variables - Mongo server
#
##############################################################################

variable "mongo_vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B1ms"
  type        = string
}

variable "mongo_image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
  type        = string
}

variable "mongo_image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
  type        = string
}

variable "mongo_image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "18.04-LTS"
  type        = string
}

variable "mongo_image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
  type        = string
}

variable "mongo_server_admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

##############################################################################
#
# * Variables - Mongo database
#
##############################################################################

variable "mongodb_admin_username" {
  description = "Database administrator username"
  type        = string
}

variable "mongodb_admin_password" {
  description = "Database Administrator password"
  type        = string
}

##############################################################################
#
# * Networking
#
##############################################################################

resource "azurerm_network_security_group" "mongo" {
  name                = "${var.prefix}-mongo-nsg"
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
    source_address_prefix      = var.mongo_ssh_source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "MONGO"
    priority                   = 305
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "27017"
    source_address_prefix      = var.webservers_subnet_prefix
    destination_address_prefix = "*"
  }
}

resource "azurerm_subnet_network_security_group_association" "mongo" {
  subnet_id                 = azurerm_subnet.mongo.id
  network_security_group_id = azurerm_network_security_group.mongo.id
}

##############################################################################
#
# * Virtual machines networking
#
##############################################################################

resource "azurerm_public_ip" "mongo" {
  name                = "${var.prefix}-mongo-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "mongo" {
  name                = "${var.prefix}-mongo-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-mongo-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.mongo.id
    public_ip_address_id          = azurerm_public_ip.mongo.id
  }
}

##############################################################################
#
# * Ubuntu Linux VMs
#
##############################################################################

resource "azurerm_linux_virtual_machine" "mongo" {
  name                = "${var.prefix}-mongo"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.mongo_vm_size
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.mongo.id, ]

  source_image_reference {
    publisher = var.mongo_image_publisher
    offer     = var.mongo_image_offer
    sku       = var.mongo_image_sku
    version   = var.mongo_image_version
  }

  os_disk {
    name                 = "${var.prefix}-mongo-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  computer_name  = "${var.prefix}-mongo"
  admin_username = var.mongo_server_admin_username

  admin_ssh_key {
    username   = var.mongo_server_admin_username
    public_key = file("keys/mongo.pem")
  }

  provisioner "file" {
    source      = "scripts/install-mongo.sh"
    destination = "/home/${var.mongo_server_admin_username}/install-mongo.sh"

    connection {
      type        = "ssh"
      user        = var.mongo_server_admin_username
      private_key = file("keys/mongo.key")
      host        = azurerm_public_ip.mongo.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.mongo_server_admin_username}/install-mongo.sh",
      "sudo /home/${var.mongo_server_admin_username}/install-mongo.sh ${var.mongodb_admin_username} ${var.mongodb_admin_password}",
    ]

    connection {
      type        = "ssh"
      user        = var.mongo_server_admin_username
      private_key = file("keys/mongo.key")
      host        = azurerm_public_ip.mongo.ip_address
    }
  }
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_metric_alert" "mongo_cpu" {
  name                = "${var.prefix}-mongo-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name

  scopes = [azurerm_linux_virtual_machine.mongo.id]

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

output "mongo_public_ip" {
  value = azurerm_public_ip.mongo.ip_address
}

output "mongo_connection_string" {
  value = "mongodb://${var.mongodb_admin_username}:<PASSWORD>@${azurerm_network_interface.mongo.private_ip_address}:27017"
}
