# Versiones y proveedor. El estado de esta carpeta queda LOCAL en la PC del dueño de la cuenta.

# BOOTSTRAP AWS · Bucket S3 para el estado compartido del grupo
# Lo ejecuta UNA sola vez el dueño de la cuenta. Su propio estado queda
# local (en esta carpeta), porque el bucket aún no existe al crearlo.
terraform {
  required_version = ">= 1.10" # use_lockfile en S3 requiere 1.10+

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = var.region

  default_tags {
    tags = {
      Proyecto   = "asistencia-grupo"
      Gestionado = "terraform"
      Uso        = "estado-terraform"
    }
  }
}
