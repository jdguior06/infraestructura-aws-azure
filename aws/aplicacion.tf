# Aplicación: secretos y cloud-init que despliega la app en cada servidor.

# Secretos generados por Terraform (quedan en el estado remoto, cifrado en S3).
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
  carpeta_cloud_init = "${path.module}/../cloud-init/amazon-linux"

  # Las claves SSH del grupo se agregan al final del cloud-config,
  # así los YAML de cloud-init/ siguen sirviendo para Pulumi y CloudFormation.
  cloud_config_claves = yamlencode({ ssh_authorized_keys = local.claves_ssh })

  user_data_backend = join("\n", [
    templatefile("${local.carpeta_cloud_init}/backend.yaml", {
      repo_url       = var.app_repo
      rama           = var.app_rama
      puerto_api     = var.puerto_backend
      cors_origin    = "http://${aws_eip.frontend.public_ip}"
      db_password    = random_password.db.result
      jwt_secret     = random_password.jwt.result
      admin_email    = var.admin_email
      admin_password = random_password.admin.result
    }),
    local.cloud_config_claves,
  ])

  user_data_frontend = join("\n", [
    templatefile("${local.carpeta_cloud_init}/frontend.yaml", {
      repo_url   = var.app_repo
      rama       = var.app_rama
      ip_backend = aws_instance.backend.private_ip
      puerto_api = var.puerto_backend
    }),
    local.cloud_config_claves,
  ])
}
