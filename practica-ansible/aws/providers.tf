# Configuración del proveedor de la nube.

# Las credenciales se toman de "aws configure"; nunca van en el código.
provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto   = var.proyecto
      Gestionado = "terraform"
    }
  }
}
