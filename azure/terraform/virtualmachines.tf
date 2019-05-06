# Launch SLES-HAE of SLES4SAP cluster nodes

# Availability set for the VMs

resource "azurerm_availability_set" "myas" {
  name                        = "myas"
  location                    = "${var.az_region}"
  resource_group_name         = "${azurerm_resource_group.myrg.name}"
  platform_fault_domain_count = 2
  managed                     = "true"

  tags {
    workspace = "${terraform.workspace}"
  }
}

# iSCSI server VM

resource "azurerm_virtual_machine" "iscsisrv" {
  name                  = "${terraform.workspace}-iscsisrv"
  location              = "${var.az_region}"
  resource_group_name   = "${azurerm_resource_group.myrg.name}"
  network_interface_ids = ["${azurerm_network_interface.iscsisrv.id}"]
  availability_set_id   = "${azurerm_availability_set.myas.id}"
  vm_size               = "Standard_D2s_v3"

  storage_os_disk {
    name              = "iscsiOsDisk"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    publisher = "SUSE"
    offer     = "SLES-SAP-BYOS"
    sku       = "12-SP3"
    version   = "2018.08.17"
  }

  storage_data_disk {
    name              = "iscsiDevices"
    caching           = "ReadWrite"
    create_option     = "Empty"
    disk_size_gb      = "10"
    lun               = "0"
    managed_disk_type = "Standard_LRS"
  }

  os_profile {
    computer_name  = "iscsisrv"
    admin_username = "${var.admin_user}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_user}/.ssh/authorized_keys"
      key_data = "${file(var.public_key_location)}"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mytfstorageacc.primary_blob_endpoint}"
  }

  connection {
    type        = "ssh"
    user        = "${var.admin_user}"
    private_key = "${file("${var.private_key_location}")}"
  }

  provisioner "file" {
    source      = "init-iscsi.sh"
    destination = "/home/${var.admin_user}/init-iscsi.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_user}/*.sh",
      "/home/${var.admin_user}/init-iscsi.sh",
    ]
  }

  tags {
    workspace = "${terraform.workspace}"
  }
}

# Cluster Nodes

resource "azurerm_virtual_machine" "clusternodes" {
  count                 = "${var.ninstances}"
  name                  = "${terraform.workspace}-node-${count.index}"
  location              = "${var.az_region}"
  resource_group_name   = "${azurerm_resource_group.myrg.name}"
  network_interface_ids = ["${element(azurerm_network_interface.clusternodes.*.id, count.index)}"]
  availability_set_id   = "${azurerm_availability_set.myas.id}"
  vm_size               = "${var.instancetype}"

  storage_os_disk {
    name              = "NodeOsDisk-${count.index}"
    caching           = "ReadWrite"
    create_option     = "FromImage"
    managed_disk_type = "Premium_LRS"
  }

  storage_image_reference {
    # XXX: The join() is a workaround for https://github.com/hashicorp/terraform/issues/11566
    id        = "${var.use_custom_image == "true" ? "${join("", azurerm_image.custom.*.id)}" : ""}"
    publisher = "${var.use_custom_image != "true" ? "SUSE" : ""}"
    offer     = "${var.use_custom_image != "true" ? "SLES-SAP-BYOS" : ""}"
    sku       = "${var.use_custom_image != "true" ? "12-SP3" : ""}"
    version   = "${var.use_custom_image != "true" ? "2018.08.17" : ""}"
  }

  storage_data_disk {
    name              = "node-data-disk-${count.index}"
    managed_disk_type = "Standard_LRS"
    create_option     = "Empty"
    lun               = 0
    disk_size_gb      = "60"
  }

  os_profile {
    computer_name  = "node-${count.index}"
    admin_username = "${var.admin_user}"
  }

  os_profile_linux_config {
    disable_password_authentication = true

    ssh_keys {
      path     = "/home/${var.admin_user}/.ssh/authorized_keys"
      key_data = "${file(var.public_key_location)}"
    }
  }

  boot_diagnostics {
    enabled     = "true"
    storage_uri = "${azurerm_storage_account.mytfstorageacc.primary_blob_endpoint}"
  }

  connection {
    type        = "ssh"
    user        = "${var.admin_user}"
    private_key = "${file("${var.private_key_location}")}"
  }

  provisioner "file" {
    source      = "init-nodes.sh"
    destination = "/home/${var.admin_user}/init-nodes.sh"
  }

  provisioner "file" {
    source      = "./provision/"
    destination = "/tmp/"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /home/${var.admin_user}/*.sh",
      "/home/${var.admin_user}/init-nodes.sh ${var.init-type} ${var.instmaster} ${var.instmaster_user} ${var.instmaster_pass}",
    ]
  }

  tags {
    workspace = "${terraform.workspace}"
  }
}
