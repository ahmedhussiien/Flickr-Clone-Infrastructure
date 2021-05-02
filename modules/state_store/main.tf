resource "azurerm_storage_container" "this" {
  name                  = "${var.prefix}-tfstate-container"
  storage_account_name  = var.storage_account_name
  container_access_type = "private"
}
