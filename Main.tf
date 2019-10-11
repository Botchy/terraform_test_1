variable "terraform_rg_location" {}
variable "terraform_rg" {}
variable "resource_prefix" {}
variable "terraform_vnet_address_space" {}
variable "terraform_vnet_address_prefix" {}  
variable "terraform_server_name" {}
variable "environment" {}
variable "terraform_server_count" {}
#variable "webserver_subnets" {
#    type = "list"
#}
# new line

variable "subscription_id" {}
variable "client_id" {}
variable "client_secret" {}
variable "tenant_id" {}

provider "azurerm" {
version                             = "1.34"
client_id                           = "${var.client_id}"
client_secret                       = "${var.client_secret}"
tenant_id                           = "${var.tenant_id}"
subscription_id                     = "${var.subscription_id}"
}

resource "azurerm_resource_group" "terraform_rg" {
    name                            = "${var.terraform_rg}"
    location                        = "${var.terraform_rg_location}"
}

resource "azurerm_virtual_network" "terraform_vnet" {
    name                            = "${var.resource_prefix}-vnet"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"
    address_space                   = ["${var.terraform_vnet_address_space}"]
}

resource "azurerm_subnet" "default" {
    name                            = "${var.resource_prefix}-subnet"
#   name                            = "${var.resource_prefix}-${substr(var.webserver_subnets[count.index], 0, length(var.webserver_subnets[count.index] - 3)}-subnet"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"
    virtual_network_name            = "${azurerm_virtual_network.terraform_vnet.name}"
   #address_prefix                  = "${var.webserver_subnets[count.index]}"
    address_prefix                  = "${var.terraform_vnet_address_prefix}"
    network_security_group_id       = "${azurerm_network_security_group.web_server_NSG.id}"
   #count                           = "${var.webserver_subnets}"
}

resource "azurerm_network_interface" "terraform_server1_nic" {
    name                            = "${var.terraform_server_name}-${format("%02d",count.index)}-nic"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"
    count                           = "${var.terraform_server_count}"

    ip_configuration {
    name                            = "${var.terraform_server_name}-${format("%02d",count.index)}-ip"
    subnet_id                       = "${azurerm_subnet.default.id}"
    private_ip_address_allocation   = "dynamic"
    public_ip_address_id            = "${azurerm_public_ip.terraform_server_public_ip.*.id[count.index]}"
    }
}

resource "azurerm_public_ip" "terraform_server_public_ip" {
    name                            = "${var.terraform_server_name}-${format("%02d",count.index)}-public-ip"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"
    # public_ip_address_allocation  = "dynamic" (deprecated)
    #allocation_method              = "Dynamic"  --> marche ok
    #allocation_method              = "${var.environment == "Dev" ? "static" : "dynamic"}"  -->  marche PAS!
    public_ip_address_allocation    = "${var.environment == "Dev" ? "static" : "dynamic"}"
    count                           = "${var.terraform_server_count}"
}
resource "azurerm_network_security_group" "web_server_NSG" {
    name                            = "${var.terraform_server_name}-nsg"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"   
}
resource "azurerm_network_security_rule" "web_server_nsg_rule_rdp" {
    name                            = "RDP Inbound"
    priority                        = 100
    direction                       = "Inbound"
    access                          = "Allow"
    protocol                        = "TCP"
    source_port_range               = "*"
    destination_port_range          = "3389"
    source_address_prefix           = "*"
    destination_address_prefix      = "*"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}" 
    network_security_group_name     = "${azurerm_network_security_group.web_server_NSG.name}" 
    }
resource "azurerm_virtual_machine" "Server1" {
    name                            = "${var.terraform_server_name}-${format("%02d",count.index)}"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}"   
    network_interface_ids           = ["${azurerm_network_interface.terraform_server1_nic.*.id[count.index]}"]
    vm_size                         = "standard_b1s"
    availability_set_id             = "${azurerm_availability_set.terraform_server_availability_set.id}"
    count                           = "${var.terraform_server_count}"

    storage_image_reference {
        publisher                   = "MicrosoftWindowsServer"
        offer                       = "WindowsServer"
        sku                         = "2016-Datacenter-Server-Core-smalldisk"
        version                     = "latest"
    }
    storage_os_disk {
        name                        = "${var.terraform_server_name}-${format("%02d",count.index)}-os_disk"
        caching                     = "Readwrite"
        create_option               = "FromImage"
        managed_disk_type           = "Standard_LRS"
    }

    os_profile {
        computer_name               = "${var.terraform_server_name}-${format("%02d",count.index)}" 
        admin_username              = "admin-azure"
        admin_password              = "Terraform1234"
    }

    os_profile_windows_config {
    }
}

resource "azurerm_availability_set" "terraform_server_availability_set" {
    name                            = "${var.resource_prefix}-availability-set"
    location                        = "${var.terraform_rg_location}"
    resource_group_name             = "${azurerm_resource_group.terraform_rg.name}" 
    managed                         = true 
    platform_fault_domain_count     = 2
}