# Valores configurables del proyecto.

variable "proyecto" {
  description = "Prefijo para los nombres de los recursos (distinto al de las prácticas anteriores)."
  type        = string
  default     = "asistencia-ansible"
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-2"
}

variable "ssh_permitido" {
  description = "Desde dónde se permite SSH (Ansible entra por aquí). Para restringirlo usa tu IP con /32."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_permitido, 0))
    error_message = "ssh_permitido debe estar en formato CIDR, por ejemplo 0.0.0.0/0 o 190.10.20.30/32."
  }
}

variable "tipo_instancia_frontend" {
  description = "Tamaño del frontend (Nginx)."
  type        = string
  default     = "t3.micro"
}

variable "tipo_instancia_backend" {
  description = "Tamaño del backend (API NestJS)."
  type        = string
  default     = "t3.micro"
}

variable "tipo_instancia_base" {
  description = "Tamaño del servidor de base de datos (PostgreSQL)."
  type        = string
  default     = "t3.micro"
}

variable "disco_backend_gb" {
  description = "Disco del backend en GB (código, node_modules y compilación)."
  type        = number
  default     = 12
}

variable "disco_base_gb" {
  description = "Disco de la base de datos en GB."
  type        = number
  default     = 20
}

variable "puerto_backend" {
  description = "Puerto de la API."
  type        = number
  default     = 3000
}

# IPs privadas fijas: así Ansible y los firewalls siempre saben dónde está cada servidor.
variable "ip_privada" {
  description = "IP privada fija de cada servidor (dentro de 10.0.1.0/24)."
  type        = map(string)
  default = {
    frontend = "10.0.1.20"
    backend  = "10.0.1.10"
    base     = "10.0.1.30"
  }
}
