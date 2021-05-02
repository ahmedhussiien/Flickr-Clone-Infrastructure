locals {
  environment = "stage"
  url         = "${var.dns_record_name}.${var.dns_zone_name}"

  tags = merge({
    "project"     = var.project_name,
    "environment" = local.environment
  }, var.extra_tags)
}

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~>2.0"
    }
  }

  backend "azurerm" {
    key = "stage/terraform.tfstate"
  }
}

##############################################################################
#
# * Resource group with a virtual network and subnet
#
##############################################################################
resource "azurerm_resource_group" "this" {
  name     = var.resource_group_name
  location = var.resource_group_location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "${var.prefix}-vnet"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  address_space       = ["${var.address_space}"]
  tags                = local.tags
}

resource "azurerm_subnet" "this" {
  name                 = "${var.prefix}-subnet"
  virtual_network_name = azurerm_virtual_network.this.name
  resource_group_name  = azurerm_resource_group.this.name
  address_prefixes     = [var.subnet_prefix]
}

##############################################################################
#
# * Networking
#
##############################################################################
resource "azurerm_network_security_group" "this" {
  name                = "${var.prefix}-sg"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  security_rule {
    name                       = "HTTP"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = var.source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "HTTPS"
    priority                   = 101
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = var.source_network
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "SSH"
    priority                   = 102
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = var.source_network
    destination_address_prefix = "*"
  }
}

resource "azurerm_public_ip" "this" {
  name                = "${var.prefix}-ip"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  allocation_method   = "Dynamic"
  tags                = local.tags
}

resource "azurerm_network_interface" "this" {
  name                = "${var.prefix}-nic"
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  ip_configuration {
    name                          = "${var.prefix}-ipconfig"
    private_ip_address_allocation = "Dynamic"
    subnet_id                     = azurerm_subnet.this.id
    public_ip_address_id          = azurerm_public_ip.this.id
  }
}

resource "azurerm_network_interface_security_group_association" "this" {
  network_interface_id      = azurerm_network_interface.this.id
  network_security_group_id = azurerm_network_security_group.this.id
}

##############################################################################
#
# * Create DNS records
#
##############################################################################
resource "azurerm_dns_a_record" "this" {
  name                = var.dns_record_name
  zone_name           = var.dns_zone_name
  resource_group_name = var.domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.this.id
}

resource "azurerm_dns_a_record" "this-www" {
  name                = "www.${var.dns_record_name}"
  zone_name           = var.dns_zone_name
  resource_group_name = var.domain_resource_group_name
  ttl                 = 300
  target_resource_id  = azurerm_public_ip.this.id
}

##############################################################################
#
# * Build an Ubuntu Linux VM
#
##############################################################################
resource "azurerm_linux_virtual_machine" "this" {
  name                = "${var.vm_hostname}-site"
  size                = var.vm_size
  location            = azurerm_resource_group.this.location
  resource_group_name = azurerm_resource_group.this.name
  tags                = local.tags

  network_interface_ids = [azurerm_network_interface.this.id, ]

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  os_disk {
    name                 = "${var.vm_hostname}-osdisk"
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  # Linux administration settings
  computer_name  = var.vm_hostname
  admin_username = var.admin_username

  admin_ssh_key {
    username   = var.admin_username
    public_key = file("keys/stage.pem")
  }

  # Copy configuration script
  provisioner "file" {
    source      = "scripts/setup.sh"
    destination = "/home/${var.admin_username}/setup.sh"

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("keys/stage.key")
      host        = azurerm_linux_virtual_machine.this.public_ip_address
    }
  }

  # Run configuration script
  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_username}/setup.sh",
      "sudo /home/${var.admin_username}/setup.sh ${local.url} ${var.certbot_email}",
    ]

    connection {
      type        = "ssh"
      user        = var.admin_username
      private_key = file("keys/stage.key")
      host        = azurerm_linux_virtual_machine.this.public_ip_address
    }
  }
}

##############################################################################
#
# * Storage account
#
##############################################################################
resource "azurerm_storage_account" "this" {
  name                     = var.storage_account_name
  resource_group_name      = azurerm_resource_group.this.name
  location                 = azurerm_resource_group.this.location
  account_tier             = "Standard"
  account_replication_type = "LRS"

  tags = local.tags
}

##############################################################################
#
# * VM Usage alert
#
##############################################################################
resource "azurerm_monitor_action_group" "this" {
  name                = "${var.prefix}-actiongroup"
  short_name          = var.prefix
  resource_group_name = azurerm_resource_group.this.name

  email_receiver {
    name          = var.alert_mailbox_name
    email_address = var.alert_mailbox
  }
}

resource "azurerm_monitor_metric_alert" "cpu_metric_alert" {
  name                = "${var.prefix}-cpu-metricalert"
  resource_group_name = azurerm_resource_group.this.name
  scopes              = [azurerm_linux_virtual_machine.this.id]
  description         = "Action will be triggered when Transactions count is greater than 70."

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Percentage CPU"
    aggregation      = "Average"
    operator         = "GreaterThan"
    threshold        = var.vm_cpu_threshold
  }

  action {
    action_group_id = azurerm_monitor_action_group.this.id
  }
}
