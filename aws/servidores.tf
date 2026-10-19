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
  user_data              = local.user_data

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
  user_data              = local.user_data

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

# IP fija para el frontend.
resource "aws_eip" "frontend" {
  instance   = aws_instance.frontend.id
  domain     = "vpc"
  depends_on = [aws_internet_gateway.principal]

  tags = { Name = "${var.proyecto}-ip-frontend" }
}
