# Red: red virtual, subred, IPs y salida a internet.

data "aws_availability_zones" "disponibles" {
  state = "available"
}

resource "aws_vpc" "principal" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = { Name = "${var.proyecto}-vpc" }
}

resource "aws_internet_gateway" "principal" {
  vpc_id = aws_vpc.principal.id

  tags = { Name = "${var.proyecto}-igw" }
}

resource "aws_subnet" "publica" {
  vpc_id                  = aws_vpc.principal.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = data.aws_availability_zones.disponibles.names[0]
  map_public_ip_on_launch = true

  tags = { Name = "${var.proyecto}-subred-publica" }
}

resource "aws_route_table" "publica" {
  vpc_id = aws_vpc.principal.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.principal.id
  }

  tags = { Name = "${var.proyecto}-rt-publica" }
}

resource "aws_route_table_association" "publica" {
  subnet_id      = aws_subnet.publica.id
  route_table_id = aws_route_table.publica.id
}
