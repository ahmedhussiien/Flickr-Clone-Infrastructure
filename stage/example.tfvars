##############################################################################
#
# * Project
#
##############################################################################

project_name            = ""
resource_group_name     = ""
resource_group_location = ""
prefix                  = "flickr-stage"
extra_tags              = {}

domain_resource_group_name  = "Domains"
dns_zone_name               = "example.com"
jenkins_dns_record_name     = "jenkins"

##############################################################################
#
# * Alerts
#
##############################################################################

alert_mailbox      = "devops@gmail.com"
alert_mailbox_name = "sendtodevops"
vm_cpu_threshold   = 60

##############################################################################
#
# * Webservers
#
##############################################################################

webservers_vm_size          = "Standard_B1ms"
webservers_image_publisher  = "Canonical"
webservers_image_offer      = "UbuntuServer"
webservers_image_sku        = "18.04-LTS"
webservers_image_version    = "latest"
webservers_admin_username   = "azureuser"

webservers_config_repo_url  = ""

##############################################################################
#
# * Redis
#
##############################################################################

redis_vm_size                   = "Standard_B1ls"
redis_image_publisher           = "Canonical"
redis_image_offer               = "UbuntuServer"
redis_image_sku                 = "18.04-LTS"
redis_image_version             = "latest"
redis_server_admin_username     = "azureuser"

redis_admin_password            = ""

##############################################################################
#
# * Mongo
#
##############################################################################

mongo_vm_size                   = "Standard_B1ms"
mongo_image_publisher           = "Canonical"
mongo_image_offer               = "UbuntuServer"
mongo_image_sku                 = "18.04-LTS"
mongo_image_version             = "latest"
mongo_server_admin_username     = "azureuser"

mongodb_admin_username  = ""
mongodb_admin_password  = ""

##############################################################################
#
# * Jenkins
#
##############################################################################

jenkins_vm_size                   = "Standard_B1ms"
jenkins_image_publisher           = "Canonical"
jenkins_image_offer               = "UbuntuServer"
jenkins_image_sku                 = "18.04-LTS"
jenkins_image_version             = "latest"
jenkins_server_admin_username     = "azureuser"

jenkins_certbot_email             = "example@gmail.com"