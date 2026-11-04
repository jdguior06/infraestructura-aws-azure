# Aplicación: secretos y cloud-init que despliega la app en cada servidor.

# Secretos generados por Terraform (quedan en el estado remoto, en Azure Storage).
# Sin caracteres especiales para que no rompan el .env ni el SQL.
resource "random_password" "db" {
  length  = 24
  special = false
}

resource "random_password" "jwt" {
  length  = 48
  special = false
}

resource "random_password" "admin" {
  length  = 16
  special = false
}

locals {
  carpeta_cloud_init = "${path.module}/../cloud-init/ubuntu"

  # En Azure las claves SSH van en admin_ssh_key, así que el cloud-init va tal cual.
  # custom_data se entrega en base64.
  custom_data_backend = base64encode(templatefile("${local.carpeta_cloud_init}/backend.yaml", {
    repo_url       = var.app_repo
    rama           = var.app_rama
    puerto_api     = var.puerto_backend
    cors_origin    = "http://${azurerm_public_ip.frontend.ip_address}"
    db_password    = random_password.db.result
    jwt_secret     = random_password.jwt.result
    admin_email    = var.admin_email
    admin_password = random_password.admin.result
  }))

  custom_data_frontend = base64encode(templatefile("${local.carpeta_cloud_init}/frontend.yaml", {
    repo_url   = var.app_repo
    rama       = var.app_rama
    ip_backend = var.ip_privada_backend
    puerto_api = var.puerto_backend
  }))
}
