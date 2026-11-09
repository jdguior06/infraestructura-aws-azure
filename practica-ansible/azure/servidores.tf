# Servidores: frontend (Nginx), backend (API) y base (PostgreSQL).
# Se crean "vacíos": solo con las claves SSH. Los configura Ansible.

resource "azurerm_linux_virtual_machine" "servidor" {
  for_each = local.roles

  name                            = "vm-${var.proyecto}-${each.key}"
  computer_name                   = each.key
  resource_group_name             = azurerm_resource_group.principal.name
  location                        = azurerm_resource_group.principal.location
  size                            = var.tamano[each.key]
  admin_username                  = var.usuario_admin
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.servidor[each.key].id]
  tags                            = merge(local.etiquetas, { Rol = each.key })

  # Una clave por integrante (archivos .pub de la carpeta claves/).
  # Si cambian las claves, Azure recrea la VM.
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
    disk_size_gb         = each.key == "base" ? var.disco_base_gb : null
  }

  source_image_reference {
    publisher = local.imagen_ubuntu.publisher
    offer     = local.imagen_ubuntu.offer
    sku       = local.imagen_ubuntu.sku
    version   = local.imagen_ubuntu.version
  }
}
