
##############################################################################
#
# * Variables - Networking
#
##############################################################################

variable "jenkins_ssh_source_network" {
  description = "Allow SSH access from this network prefix. Defaults to '*'."
  default     = "*"
}

locals {
  jenkins_domain = "${var.jenkins_dns_record_name}.${var.dns_zone_name}"
}

##############################################################################
#
# * Variables - Jenkins server
#
##############################################################################

variable "jenkins_vm_size" {
  description = "Specifies the size of the virtual machine."
  default     = "Standard_B1ms"
  type        = string
}

variable "jenkins_image_publisher" {
  description = "Name of the publisher of the image (az vm image list)"
  default     = "Canonical"
  type        = string
}

variable "jenkins_image_offer" {
  description = "Name of the offer (az vm image list)"
  default     = "UbuntuServer"
  type        = string
}

variable "jenkins_image_sku" {
  description = "Image SKU to apply (az vm image list)"
  default     = "18.04-LTS"
  type        = string
}

variable "jenkins_image_version" {
  description = "Version of the image to apply (az vm image list)"
  default     = "latest"
  type        = string
}

variable "jenkins_server_admin_username" {
  description = "Administrator user name"
  default     = "adminuser"
}

variable "jenkins_certbot_email" {
  description = "The email address used for certbot ssl notifications."
  type        = string
}

##############################################################################
#
# * Networking
#
##############################################################################

resource "azurerm_network_security_group" "jenkins" {
  name                = "${var.prefix}-jenkins-nsg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "SSH"
    priority                   = 290
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.jenkins_ssh_source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
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
}

resource "azurerm_subnet_network_security_group_association" "jenkins" {
  subnet_id                 = azurerm_subnet.jenkins.id
  network_security_group_id = azurerm_network_security_group.jenkins.id
}

##############################################################################
#
# * Virtual machines networking
#
##############################################################################

resource "azurerm_public_ip" "jenkins" {
  name                = "${var.prefix}-jenkins-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Static"
  tags                = local.tags
}

resource "azurerm_network_interface" "jenkins" {
  name                = "${var.prefix}-jenkins-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-jenkins-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.jenkins.id
    public_ip_address_id          = azurerm_public_ip.jenkins.id
  }
}

##############################################################################
#
# * Ubuntu Linux VMs
#
##############################################################################

resource "azurerm_linux_virtual_machine" "jenkins" {
  name                = "${var.prefix}-jenkins"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  size                = var.jenkins_vm_size
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.jenkins.id, ]

  source_image_reference {
    publisher = var.jenkins_image_publisher
    offer     = var.jenkins_image_offer
    sku       = var.jenkins_image_sku
    version   = var.jenkins_image_version
  }

  os_disk {
    name                 = "${var.prefix}-jenkins-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  computer_name  = "${var.prefix}-jenkins"
  admin_username = var.jenkins_server_admin_username

  admin_ssh_key {
    username   = var.jenkins_server_admin_username
    public_key = file("keys/jenkins.pem")
  }

  provisioner "file" {
    source      = "scripts"
    destination = "/home/${var.jenkins_server_admin_username}"

    connection {
      type        = "ssh"
      user        = var.jenkins_server_admin_username
      private_key = file("keys/jenkins.key")
      host        = azurerm_public_ip.jenkins.ip_address
    }
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.jenkins_server_admin_username}/scripts/*",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/install-docker.sh",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/install-npm.sh",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/install-certbot.sh",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/issue-cert.sh ${local.jenkins_domain} ${var.jenkins_certbot_email}",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/install-jenkins.sh",
      "sudo /home/${var.jenkins_server_admin_username}/scripts/config-jenkins-ssl.sh ${local.jenkins_domain}"
    ]

    connection {
      type        = "ssh"
      user        = var.jenkins_server_admin_username
      private_key = file("keys/jenkins.key")
      host        = azurerm_public_ip.jenkins.ip_address
    }
  }
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################

resource "azurerm_monitor_metric_alert" "jenkins_cpu" {
  name                = "${var.prefix}-jenkins-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name

  scopes = [azurerm_linux_virtual_machine.jenkins.id]

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

output "jenkins_public_ip" {
  value = azurerm_public_ip.jenkins.ip_address
}

output "jenkins_url" {
  value = local.jenkins_domain
}
