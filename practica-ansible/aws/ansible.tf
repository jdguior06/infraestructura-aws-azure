# Inventario de Ansible: Terraform lo escribe con las IPs de cada servidor.
# Queda en ../ansible/inventarios/aws.ini (no se sube a git: lo genera cada uno).

resource "local_file" "inventario_ansible" {
  filename        = "${path.module}/../ansible/inventarios/aws.ini"
  file_permission = "0644"

  content = templatefile("${path.module}/../ansible/inventarios/inventario.tftpl", {
    nube    = "aws"
    usuario = "ec2-user"
    frontend = {
      publica = aws_eip.frontend.public_ip
      privada = aws_instance.servidor["frontend"].private_ip
    }
    backend = {
      publica = aws_instance.servidor["backend"].public_ip
      privada = aws_instance.servidor["backend"].private_ip
    }
    base = {
      publica = aws_instance.servidor["base"].public_ip
      privada = aws_instance.servidor["base"].private_ip
    }
  })

  # La IP pública del frontend cambia al asociar la Elastic IP.
  depends_on = [aws_eip_association.frontend]
}
