# Valores configurables del proyecto.

variable "proyecto" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
  default     = "asistencia-grupo"
}

variable "region" {
  description = "Región de AWS."
  type        = string
  default     = "us-east-2"
}

variable "ssh_permitido" {
  description = "Desde dónde se permite SSH. Abierto para la práctica; para restringirlo usa una IP con /32."
  type        = string
  default     = "0.0.0.0/0"

  validation {
    condition     = can(cidrhost(var.ssh_permitido, 0))
    error_message = "ssh_permitido debe estar en formato CIDR, por ejemplo 0.0.0.0/0 o 190.10.20.30/32."
  }
}

variable "tipo_instancia_backend" {
  description = "Tamaño del backend (API Express + PostgreSQL)."
  type        = string
  default     = "t3.micro"
}

variable "tipo_instancia_frontend" {
  description = "Tamaño del frontend (Nginx con archivos estáticos)."
  type        = string
  default     = "t3.micro"
}

variable "disco_backend_gb" {
  description = "Disco del backend en GB (ahí vive también la base de datos)."
  type        = number
  default     = 20
}

variable "puerto_backend" {
  description = "Puerto en el que escucha la API de Express."
  type        = number
  default     = 3000
}
