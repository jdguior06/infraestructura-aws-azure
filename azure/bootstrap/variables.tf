# Valores configurables del bootstrap.

variable "subscription_id" {
  description = "ID de la suscripción compartida: az account show --query id -o tsv"
  type        = string
}

variable "region" {
  description = "Región donde vive la cuenta de almacenamiento del estado."
  type        = string
  default     = "eastus"
}
