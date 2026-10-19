# Valores calculados: claves SSH del grupo y datos comunes.

locals {
  etiquetas = {
    Proyecto   = var.proyecto
    Gestionado = "terraform"
  }

  # Claves públicas SSH del grupo, guardadas en el repositorio (carpeta claves/).
  # Así el plan es igual sin importar quién lo ejecute.
  carpeta_claves = "${path.module}/../claves"

  claves_ssh = [
    for archivo in sort(fileset(local.carpeta_claves, "*.pub")) :
    trimspace(file("${local.carpeta_claves}/${archivo}"))
  ]

  # Ubuntu Server 24.04 LTS (usa apt).
  imagen_ubuntu = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}
