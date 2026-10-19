# CAMBIO B: un tercer servidor (sin IP pública, solo red interna).

# Tarjeta de red con IP privada fija.
resource "azurerm_network_interface" "extra" {
  name                = "nic-maquina2-jorgeprueba"
  resource_group_name = azurerm_resource_group.principal.name
  location            = azurerm_resource_group.principal.location
  tags                = local.etiquetas

  ip_configuration {
    name                          = "interna"
    subnet_id                     = azurerm_subnet.servidores.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.1.30"
  }
}

resource "azurerm_linux_virtual_machine" "extra" {
  name                            = "maquina2-jorgeprueba"
  resource_group_name             = azurerm_resource_group.principal.name
  location                        = azurerm_resource_group.principal.location
  size                            = var.tamano_frontend
  admin_username                  = var.usuario_admin
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.extra.id]
  tags                            = merge(local.etiquetas, { Rol = "extra" })

  # Una clave por integrante (archivos .pub de la carpeta claves/).
  dynamic "admin_ssh_key" {
    for_each = local.claves_ssh

    content {
      username   = var.usuario_admin
      public_key = admin_ssh_key.value
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
  }

  source_image_reference {
    publisher = local.imagen_ubuntu.publisher
    offer     = local.imagen_ubuntu.offer
    sku       = local.imagen_ubuntu.sku
    version   = local.imagen_ubuntu.version
  }
}
