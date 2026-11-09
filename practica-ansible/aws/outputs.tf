# Salidas: IPs, URL y comandos SSH.

output "url_app" {
  description = "Dirección de la app cuando Ansible termine."
  value       = "http://${aws_eip.frontend.public_ip}"
}

output "ips" {
  description = "IP pública (SSH/Ansible) y privada de cada servidor."
  value = {
    frontend = { publica = aws_eip.frontend.public_ip, privada = aws_instance.servidor["frontend"].private_ip }
    backend  = { publica = aws_instance.servidor["backend"].public_ip, privada = aws_instance.servidor["backend"].private_ip }
    base     = { publica = aws_instance.servidor["base"].public_ip, privada = aws_instance.servidor["base"].private_ip }
  }
}

output "ssh" {
  description = "Comandos para entrar a cada servidor."
  value = {
    frontend = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_eip.frontend.public_ip}"
    backend  = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_instance.servidor["backend"].public_ip}"
    base     = "ssh -i ~/.ssh/id_ed25519 ec2-user@${aws_instance.servidor["base"].public_ip}"
  }
}

output "inventario_ansible" {
  description = "Archivo de inventario generado para Ansible."
  value       = "practica-ansible/ansible/inventarios/aws.ini"
}
