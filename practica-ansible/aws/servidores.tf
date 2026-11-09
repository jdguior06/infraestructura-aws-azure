# Servidores: frontend (Nginx), backend (API) y base (PostgreSQL).
# Se crean "vacíos": solo con las claves SSH. Los configura Ansible.

# Amazon Linux 2023 más reciente (usa dnf).
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

locals {
  # Lo que cambia entre los tres servidores; el resto es igual.
  servidores = {
    frontend = { tipo = var.tipo_instancia_frontend, disco = null, grupo = aws_security_group.frontend.id }
    backend  = { tipo = var.tipo_instancia_backend, disco = var.disco_backend_gb, grupo = aws_security_group.backend.id }
    base     = { tipo = var.tipo_instancia_base, disco = var.disco_base_gb, grupo = aws_security_group.base.id }
  }
}

resource "aws_instance" "servidor" {
  for_each = local.servidores

  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = each.value.tipo
  subnet_id              = aws_subnet.publica.id
  private_ip             = var.ip_privada[each.key]
  vpc_security_group_ids = [each.value.grupo]

  # Solo las claves SSH. Si cambian las claves, se recrea el servidor.
  user_data                   = local.user_data
  user_data_replace_on_change = true

  root_block_device {
    volume_size = each.value.disco # null = el tamaño de la imagen (8 GB)
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  lifecycle {
    # No recrear el servidor cuando AWS publique una imagen nueva.
    ignore_changes = [ami]

    precondition {
      condition     = length(local.claves_ssh) > 0
      error_message = "No hay claves en la carpeta claves/. Agrega al menos un archivo .pub."
    }
  }

  tags = {
    Name = "${var.proyecto}-${each.key}"
    Rol  = each.key
  }
}

# IP fija para el frontend: es la dirección de la app.
resource "aws_eip" "frontend" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.principal]

  tags = { Name = "${var.proyecto}-ip-frontend" }
}

resource "aws_eip_association" "frontend" {
  instance_id   = aws_instance.servidor["frontend"].id
  allocation_id = aws_eip.frontend.id
}
