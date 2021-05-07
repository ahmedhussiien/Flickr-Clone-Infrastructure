
##############################################################################
#
# * Variables - Networking
#
##############################################################################

variable "webservers_ssh_source_network" {
  description = "Allow SSH access from this network prefix. Defaults to '*'."
  default     = "*"
}

##############################################################################
#
# * Variables - web servers
#
##############################################################################

variable "webservers_vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B1ls"
  type        = string
}

variable "webservers_image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
  type        = string
}

variable "webservers_image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
  type        = string
}

variable "webservers_image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "18.04-LTS"
  type        = string
}

variable "webservers_image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
  type        = string
}

variable "webservers_admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

##############################################################################
#
# * Variables - web servers configuration
#
##############################################################################

variable "webservers_config_repo_url" {
  description = "Git repository containing the initial scripts"
  type        = string
}

##############################################################################
#
# * Networking
#
##############################################################################


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
    name                       = "HTTP"
    priority                   = 310
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 320
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

resource "azurerm_network_interface_security_group_association" "webserver" {
  network_interface_id      = azurerm_network_interface.webserver.id
  network_security_group_id = azurerm_network_security_group.webservers.id
}

##############################################################################
#
# * Virtual machines networking
#
##############################################################################

resource "azurerm_public_ip" "webserver" {
  name                = "${var.prefix}-webserver-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "webserver" {
  name                = "${var.prefix}-webserver-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-webserver-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.webservers.id
    public_ip_address_id          = azurerm_public_ip.webserver.id
  }
}



##############################################################################
#
# * Ubuntu Linux VMs
#
##############################################################################

resource "azurerm_linux_virtual_machine" "webserver" {
  name                = "${var.prefix}-webserver"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.webservers_vm_size
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.webserver.id, ]

  source_image_reference {
    publisher = var.webservers_image_publisher
    offer     = var.webservers_image_offer
    sku       = var.webservers_image_sku
    version   = var.webservers_image_version
  }

  os_disk {
    name                 = "${var.prefix}-webserver-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  computer_name  = var.prefix
  admin_username = var.webservers_admin_username

  admin_ssh_key {
    username   = var.webservers_admin_username
    public_key = file("keys/webservers.pem")
  }

  provisioner "file" {
    source      = "scripts/install-docker.sh"
    destination = "/home/${var.webservers_admin_username}/install-docker.sh"

    connection {
      type        = "ssh"
      user        = var.webservers_admin_username
      private_key = file("keys/webservers.key")
      host        = azurerm_public_ip.webserver.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.webservers_admin_username}/install-docker.sh",
      "sudo /home/${var.webservers_admin_username}/install-docker.sh",

      "GIT_SSH_COMMAND=\"ssh -o StrictHostKeyChecking=no\" git clone --depth 1 ${var.webservers_config_repo_url} /home/${var.webservers_admin_username}/git-tmp",
      "cp -a /home/${var.webservers_admin_username}/git-tmp/* /home/${var.webservers_admin_username}/",
      "sudo rm -r /home/${var.webservers_admin_username}/git-tmp"
    ]

    connection {
      type        = "ssh"
      user        = var.webservers_admin_username
      private_key = file("keys/webservers.key")
      host        = azurerm_public_ip.webserver.ip_address
    }
  }
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_metric_alert" "webserver_cpu" {
  name                = "${var.prefix}-webserver-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name

  scopes = [azurerm_linux_virtual_machine.webserver.id]

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

output "webservers_public_ip" {
  value = azurerm_public_ip.webserver.ip_address
}
