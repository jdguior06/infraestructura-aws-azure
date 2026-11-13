# Valores configurables del proyecto.

variable "subscription_id" {
  description = "ID de la suscripción compartida (la misma para todo el grupo)."
  type        = string
}

variable "proyecto" {
  description = "Prefijo para los nombres de los recursos (distinto al de las prácticas anteriores)."
  type        = string
  default     = "asistencia-ansible"
}

variable "region" {
  description = "Región de Azure. eastus funcionó con Standard_D2as_v4; westus2 tiene la serie B, más barata."
  type        = string
  default     = "eastus"
}

variable "ssh_permitido" {
  description = "Desde dónde se permite SSH (Ansible entra por aquí). \"*\" lo abre; para restringirlo usa tu IP con /32."
  type        = string
  default     = "*"
}

variable "usuario_admin" {
  description = "Usuario para entrar por SSH (y el que usa Ansible)."
  type        = string
  default     = "azureuser"
}

variable "tamano" {
  description = "Tamaño de cada VM. En westus2 puedes usar Standard_B2ats_v2, más barato."
  type        = map(string)
  default = {
    frontend = "Standard_B1ms"
    backend  = "Standard_B1ms"
    base     = "Standard_B2s"
  }
}

variable "disco_base_gb" {
  description = "Disco de la base de datos en GB (mínimo 30 para Ubuntu)."
  type        = number
  default     = 30
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
