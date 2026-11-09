# Salidas: IPs, URL y comandos SSH.

output "url_app" {
  description = "Dirección de la app cuando Ansible termine."
  value       = "http://${azurerm_public_ip.servidor["frontend"].ip_address}"
}

output "ips" {
  description = "IP pública (SSH/Ansible) y privada de cada servidor."
  value = {
    for rol in local.roles : rol => {
      publica = azurerm_public_ip.servidor[rol].ip_address
      privada = azurerm_network_interface.servidor[rol].private_ip_address
    }
  }
}

output "ssh" {
  description = "Comandos para entrar a cada servidor."
  value = {
    for rol in local.roles :
    rol => "ssh -i ~/.ssh/id_ed25519 ${var.usuario_admin}@${azurerm_public_ip.servidor[rol].ip_address}"
  }
}

output "inventario_ansible" {
  description = "Archivo de inventario generado para Ansible."
  value       = "practica-ansible/ansible/inventarios/azure.ini"
}
