# Servidores: backend (API + PostgreSQL) y frontend (Nginx).

resource "azurerm_linux_virtual_machine" "backend" {
  name                            = "vm-${var.proyecto}-backend"
  resource_group_name             = azurerm_resource_group.principal.name
  location                        = azurerm_resource_group.principal.location
  size                            = var.tamano_backend
  admin_username                  = var.usuario_admin
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.backend.id]
  tags                            = merge(local.etiquetas, { Rol = "backend" })

  # Una clave por integrante (archivos .pub de la carpeta claves/).
  dynamic "admin_ssh_key" {
    for_each = local.claves_ssh

    content {
      username   = var.usuario_admin
      public_key = admin_ssh_key.value
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.claves_ssh) > 0
      error_message = "No hay claves en la carpeta claves/. Agrega al menos un archivo .pub."
    }
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "StandardSSD_LRS"
    disk_size_gb         = var.disco_backend_gb
  }

  source_image_reference {
    publisher = local.imagen_ubuntu.publisher
    offer     = local.imagen_ubuntu.offer
    sku       = local.imagen_ubuntu.sku
    version   = local.imagen_ubuntu.version
  }
}

resource "azurerm_linux_virtual_machine" "frontend" {
  name                            = "vm-${var.proyecto}-frontend-jorgeprueba"
  resource_group_name             = azurerm_resource_group.principal.name
  location                        = azurerm_resource_group.principal.location
  size                            = var.tamano_frontend
  admin_username                  = var.usuario_admin
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.frontend.id]
  tags                            = merge(local.etiquetas, { Rol = "frontend" })

  # Una clave por integrante (archivos .pub de la carpeta claves/).
  dynamic "admin_ssh_key" {
    for_each = local.claves_ssh

    content {
      username   = var.usuario_admin
      public_key = admin_ssh_key.value
    }
  }

  lifecycle {
    precondition {
      condition     = length(local.claves_ssh) > 0
      error_message = "No hay claves en la carpeta claves/. Agrega al menos un archivo .pub."
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
