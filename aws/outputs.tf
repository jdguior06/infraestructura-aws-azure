# Salidas: IPs, URL y comandos SSH.

output "url_app" {
  description = "Dirección de la app cuando Nginx esté configurado."
  value       = "http://${aws_eip.frontend.public_ip}"
}

output "frontend_ip_publica" {
  value = aws_eip.frontend.public_ip
}

output "backend_ip_publica" {
  description = "Solo para SSH. Cambia si el servidor se detiene."
  value       = aws_instance.backend.public_ip
}

output "backend_ip_privada" {
  description = "La que usará Nginx para reenviar /api."
  value       = aws_instance.backend.private_ip
}

output "ssh_frontend" {
  value = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_eip.frontend.public_ip}"
}

output "ssh_backend" {
  value = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_instance.backend.public_ip}"
}
