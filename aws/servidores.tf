# Servidores: backend (API + PostgreSQL) y frontend (Nginx).

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

resource "aws_instance" "backend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.tipo_instancia_backend
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.backend.id]

  # cloud-init instala PostgreSQL y despliega la API (ver cloud-init/amazon-linux/).
  # Solo corre en el primer arranque: si cambia, se recrea el servidor.
  user_data                   = local.user_data_backend
  user_data_replace_on_change = true

  root_block_device {
    volume_size = var.disco_backend_gb
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required" # IMDSv2
  }

  # No recrear el servidor cuando AWS publique una imagen nueva.
  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = length(local.claves_ssh) > 0
      error_message = "No hay claves en la carpeta claves/. Agrega al menos un archivo .pub."
    }
  }

  tags = {
    Name = "${var.proyecto}-backend"
    Rol  = "backend"
  }
}

resource "aws_instance" "frontend" {
  ami                    = data.aws_ami.amazon_linux.id
  instance_type          = var.tipo_instancia_frontend
  subnet_id              = aws_subnet.publica.id
  vpc_security_group_ids = [aws_security_group.frontend.id]

  # cloud-init compila el frontend y configura Nginx (ver cloud-init/amazon-linux/).
  user_data                   = local.user_data_frontend
  user_data_replace_on_change = true

  root_block_device {
    volume_type = "gp3"
    encrypted   = true
  }

  metadata_options {
    http_tokens = "required"
  }

  lifecycle {
    ignore_changes = [ami]

    precondition {
      condition     = length(local.claves_ssh) > 0
      error_message = "No hay claves en la carpeta claves/. Agrega al menos un archivo .pub."
    }
  }

  tags = {
    Name = "${var.proyecto}-frontend"
    Rol  = "frontend"
  }
}

# IP fija para el frontend. Se crea antes que los servidores porque el
# backend la necesita (CORS_ORIGIN); luego se asocia al frontend.
resource "aws_eip" "frontend" {
  domain     = "vpc"
  depends_on = [aws_internet_gateway.principal]

  tags = { Name = "${var.proyecto}-ip-frontend" }
}

resource "aws_eip_association" "frontend" {
  instance_id   = aws_instance.frontend.id
  allocation_id = aws_eip.frontend.id
}
