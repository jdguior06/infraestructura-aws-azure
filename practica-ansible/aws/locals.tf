# Valores calculados: claves SSH del grupo.

locals {
  # Claves públicas SSH del grupo (carpeta claves/ en la raíz del repo).
  carpeta_claves = "${path.module}/../../claves"

  claves_ssh = [
    for archivo in sort(fileset(local.carpeta_claves, "*.pub")) :
    trimspace(file("${local.carpeta_claves}/${archivo}"))
  ]

  # cloud-init mínimo: solo las claves SSH para que Ansible pueda entrar.
  # Toda la configuración la hace Ansible (../ansible).
  user_data = "#cloud-config\n${yamlencode({ ssh_authorized_keys = local.claves_ssh })}"
}
