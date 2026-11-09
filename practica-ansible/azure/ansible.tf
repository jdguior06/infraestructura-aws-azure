# Inventario de Ansible: Terraform lo escribe con las IPs de cada servidor.
# Queda en ../ansible/inventarios/azure.ini (no se sube a git: lo genera cada uno).

resource "local_file" "inventario_ansible" {
  filename        = "${path.module}/../ansible/inventarios/azure.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/../ansible/inventarios/inventario.tftpl", {
    nube    = "azure"
    usuario = var.usuario_admin
    frontend = {
      publica = azurerm_public_ip.servidor["frontend"].ip_address
      privada = azurerm_network_interface.servidor["frontend"].private_ip_address
    }
    backend = {
      publica = azurerm_public_ip.servidor["backend"].ip_address
      privada = azurerm_network_interface.servidor["backend"].private_ip_address
    }
    base = {
      publica = azurerm_public_ip.servidor["base"].ip_address
      privada = azurerm_network_interface.servidor["base"].private_ip_address
    }
  })

  # Que el inventario aparezca cuando las VMs ya existen.
  depends_on = [azurerm_linux_virtual_machine.servidor]
}
