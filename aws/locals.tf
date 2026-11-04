# Valores calculados: claves SSH del grupo y datos comunes.

# Claves públicas SSH del grupo, guardadas en el repositorio (carpeta claves/).
# Así el plan es igual sin importar quién lo ejecute.
locals {
  carpeta_claves = "${path.module}/../claves"

  claves_ssh = [
    for archivo in sort(fileset(local.carpeta_claves, "*.pub")) :
    trimspace(file("${local.carpeta_claves}/${archivo}"))
  ]
}
