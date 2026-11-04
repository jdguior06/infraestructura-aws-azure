# cloud-init: despliegue automático de la app

Cada VM ejecuta su archivo **una sola vez, en el primer arranque**: instala lo necesario, clona la app de GitHub, la compila y la deja corriendo.

| Archivo | Nube | Qué hace |
| --- | --- | --- |
| `amazon-linux/backend.yaml` | AWS | PostgreSQL 16, Node 22, API NestJS como servicio `asistencia-api` |
| `amazon-linux/frontend.yaml` | AWS | Node 22 para compilar, React (Vite), Nginx con proxy a `/api` |
| `ubuntu/backend.yaml` | Azure | Lo mismo que en AWS, con `apt` |
| `ubuntu/frontend.yaml` | Azure | Lo mismo que en AWS, con `apt` |

Los archivos están separados **por sistema operativo, no por herramienta**: el mismo YAML sirve con Terraform, Pulumi y CloudFormation.

## Variables de plantilla

| Variable | Archivo | De dónde sale en Terraform |
| --- | --- | --- |
| `repo_url`, `rama` | los dos | `var.app_repo`, `var.app_rama` |
| `puerto_api` | los dos | `var.puerto_backend` |
| `cors_origin` | backend | IP pública del frontend |
| `db_password`, `jwt_secret`, `admin_password` | backend | `random_password` (en `aplicacion.tf`) |
| `admin_email` | backend | `var.admin_email` |
| `ip_backend` | frontend | IP privada del backend |

Regla para que funcione en las tres herramientas: **las variables de plantilla van con llaves** (`${ip_backend}`) y **las de bash, sin llaves** (`$APP_REPO`). Así Terraform y el `Fn::Sub` de CloudFormation no confunden unas con otras.

## Claves SSH

- **AWS:** Terraform agrega `ssh_authorized_keys` al final del YAML con las claves de `claves/`.
- **Azure:** las claves van en `admin_ssh_key` de la VM; el YAML se usa tal cual.

## Revisar el despliegue

`terraform apply` termina antes que cloud-init. Entra por SSH y ejecuta:

```bash
cloud-init status --wait                       # "status: done" o "status: error"
sudo tail -n 50 /var/log/cloud-init-output.log # salida de cada paso
systemctl status asistencia-api                # backend
systemctl status nginx                         # frontend
```

Tarda entre 5 y 10 minutos (más en `t3.micro`, por la compilación).

## Actualizar la app

cloud-init no se repite. Para desplegar código nuevo:

- **Recrear el servidor** (lo más "IaC"): `terraform apply -replace="aws_instance.frontend"`. En el backend esto **borra la base de datos**.
- **A mano**, dentro del servidor:

  ```bash
  cd /opt/asistencia/app && sudo -u asistencia git pull
  # backend
  cd server && sudo -u asistencia -H npm ci && sudo -u asistencia -H npm run build \
    && sudo -u asistencia -H npm run migration:run && sudo systemctl restart asistencia-api
  # frontend
  cd client && sudo -u asistencia -H npm ci && sudo -u asistencia -H npm run build \
    && sudo cp -r dist/. /var/www/asistencia/
  ```

## Seguridad de esta práctica

Las contraseñas quedan en el `user_data` / `custom_data` de la VM y en el estado de Terraform (cifrado en S3 / Azure Storage). Es aceptable para la práctica; en producción irían en AWS Secrets Manager o Azure Key Vault.
