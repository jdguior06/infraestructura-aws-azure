# Valores configurables del proyecto.

variable "subscription_id" {
  description = "ID de la suscripción compartida (la misma para todo el grupo)."
  type        = string
}

variable "proyecto" {
  description = "Prefijo para los nombres de los recursos."
  type        = string
  default     = "asistencia-grupo"
}

variable "region" {
  description = "Región de Azure. eastus funcionó con Standard_D2as_v4; westus2 tiene la serie B, más barata."
  type        = string
  default     = "eastus"
}

variable "ssh_permitido" {
  description = "Desde dónde se permite SSH. \"*\" lo abre para la práctica; para restringirlo usa una IP con /32."
  type        = string
  default     = "*"
}

variable "usuario_admin" {
  description = "Usuario para entrar por SSH."
  type        = string
  default     = "azureuser"
}

variable "tamano_backend" {
  description = "Tamaño del backend. En westus2 puedes usar Standard_B2ats_v2, más barato."
  type        = string
  default     = "Standard_D2as_v4"
}

variable "tamano_frontend" {
  description = "Tamaño del frontend."
  type        = string
  default     = "Standard_D2as_v4"
}

variable "disco_backend_gb" {
  description = "Disco del backend en GB (mínimo 30 para Ubuntu)."
  type        = number
  default     = 30
}

variable "puerto_backend" {
  description = "Puerto en el que escucha la API de Express."
  type        = number
  default     = 3000
}

variable "ip_privada_backend" {
  description = "IP privada fija del backend (la usa Nginx para /api)."
  type        = string
  default     = "10.0.1.10"
}

variable "ip_privada_frontend" {
  description = "IP privada fija del frontend."
  type        = string
  default     = "10.0.1.20"
}
