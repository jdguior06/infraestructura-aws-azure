# Salidas: IPs, URL y comandos SSH.

output "url_app" {
  description = "Dirección de la app cuando Nginx esté configurado."
  value       = "http://${azurerm_public_ip.frontend.ip_address}"
}

output "frontend_ip_publica" {
  value = azurerm_public_ip.frontend.ip_address
}

output "backend_ip_publica" {
  description = "Solo para SSH."
  value       = azurerm_public_ip.backend.ip_address
}

output "backend_ip_privada" {
  description = "La que usará Nginx para reenviar /api."
  value       = azurerm_network_interface.backend.private_ip_address
}

output "ssh_frontend" {
  value = "ssh -i ~/.ssh/id_ed25519 ${var.usuario_admin}@${azurerm_public_ip.frontend.ip_address}"
}

output "ssh_backend" {
  value = "ssh -i ~/.ssh/id_ed25519 ${var.usuario_admin}@${azurerm_public_ip.backend.ip_address}"
}
