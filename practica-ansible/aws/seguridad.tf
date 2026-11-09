# Seguridad: un firewall por servidor. Cadena: internet → frontend → backend → base.

# ---------------------------------------------------------------- Frontend
# Web abierta a internet, SSH según var.ssh_permitido.
resource "aws_security_group" "frontend" {
  name        = "${var.proyecto}-sg-frontend"
  description = "Web publica y SSH"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.proyecto}-sg-frontend" }
}

resource "aws_vpc_security_group_ingress_rule" "frontend_http" {
  security_group_id = aws_security_group.frontend.id
  description       = "HTTP desde internet"
  ip_protocol       = "tcp"
  from_port         = 80
  to_port           = 80
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_https" {
  security_group_id = aws_security_group.frontend.id
  description       = "HTTPS desde internet"
  ip_protocol       = "tcp"
  from_port         = 443
  to_port           = 443
  cidr_ipv4         = "0.0.0.0/0"
}

resource "aws_vpc_security_group_ingress_rule" "frontend_ssh" {
  security_group_id = aws_security_group.frontend.id
  description       = "SSH segun var.ssh_permitido"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_permitido
}

resource "aws_vpc_security_group_egress_rule" "frontend_salida" {
  security_group_id = aws_security_group.frontend.id
  description       = "Salida libre: paquetes, GitHub y la API del backend"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------- Backend
# La API solo acepta tráfico del frontend.
resource "aws_security_group" "backend" {
  name        = "${var.proyecto}-sg-backend"
  description = "API solo desde el frontend y SSH"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.proyecto}-sg-backend" }
}

resource "aws_vpc_security_group_ingress_rule" "backend_api" {
  security_group_id            = aws_security_group.backend.id
  description                  = "API desde el servidor frontend"
  ip_protocol                  = "tcp"
  from_port                    = var.puerto_backend
  to_port                      = var.puerto_backend
  referenced_security_group_id = aws_security_group.frontend.id
}

resource "aws_vpc_security_group_ingress_rule" "backend_ssh" {
  security_group_id = aws_security_group.backend.id
  description       = "SSH segun var.ssh_permitido"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_permitido
}

resource "aws_vpc_security_group_egress_rule" "backend_salida" {
  security_group_id = aws_security_group.backend.id
  description       = "Salida libre: paquetes, GitHub y PostgreSQL"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}

# ---------------------------------------------------------------- Base de datos
# PostgreSQL solo acepta tráfico del backend. Ni el frontend ni internet llegan al 5432.
resource "aws_security_group" "base" {
  name        = "${var.proyecto}-sg-base"
  description = "PostgreSQL solo desde el backend y SSH"
  vpc_id      = aws_vpc.principal.id

  tags = { Name = "${var.proyecto}-sg-base" }
}

resource "aws_vpc_security_group_ingress_rule" "base_postgres" {
  security_group_id            = aws_security_group.base.id
  description                  = "PostgreSQL desde el servidor backend"
  ip_protocol                  = "tcp"
  from_port                    = 5432
  to_port                      = 5432
  referenced_security_group_id = aws_security_group.backend.id
}

resource "aws_vpc_security_group_ingress_rule" "base_ssh" {
  security_group_id = aws_security_group.base.id
  description       = "SSH segun var.ssh_permitido"
  ip_protocol       = "tcp"
  from_port         = 22
  to_port           = 22
  cidr_ipv4         = var.ssh_permitido
}

resource "aws_vpc_security_group_egress_rule" "base_salida" {
  security_group_id = aws_security_group.base.id
  description       = "Salida libre: paquetes del sistema"
  ip_protocol       = "-1"
  cidr_ipv4         = "0.0.0.0/0"
}
