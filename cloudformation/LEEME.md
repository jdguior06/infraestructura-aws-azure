# CloudFormation · plantillas anidadas + Git sync + cloud-init

La misma infraestructura de `aws/` (Terraform) y `pulumi/aws/`, en CloudFormation puro. Los servidores se despliegan solos con cloud-init y **nadie ejecuta el despliegue desde su PC**: CloudFormation Git sync aplica cada merge a `main`.

```
Integrante ── PR ──► GitHub (main) ── Git sync ──► Stack asistencia-cfn
                     │                                ├─ RedStack       (red.yaml)
                     ├─ plantillas/main.yaml  ◄─vigila ├─ SeguridadStack (seguridad.yaml)
                     └─ git-sync/deployment.yaml ◄─vigila ├─ BackendStack (backend.yaml)
                                                      └─ FrontendStack  (frontend.yaml)
             las 4 anidadas se leen de S3: s3://<bucket>/cloudformation/<version>/
```

```
cloudformation/
├── plantillas/
│   ├── main.yaml               plantilla raíz: parámetros, 4 stacks anidados y salidas
│   └── anidadas/
│       ├── red.yaml            VPC, subred, rutas, IP fija del frontend
│       ├── seguridad.yaml      security groups de frontend y backend
│       ├── backend.yaml        EC2 + cloud-init (PostgreSQL, NestJS)
│       └── frontend.yaml       EC2 + cloud-init (React, Nginx) + asociación de la IP
├── git-sync/deployment.yaml    parámetros del stack (Git sync lo vigila)
└── scripts/
    ├── publicar-anidadas.ps1   sube las anidadas a S3 y actualiza deployment.yaml
    └── verificar.sh            revisión automática de cada PR (GitHub Actions)
```

## El problema de las anidadas en S3, y cómo se resuelve aquí

Git sync solo vigila `main.yaml` y `deployment.yaml`. Las plantillas anidadas, CloudFormation las lee de S3. Si alguien cambia `backend.yaml` y hace merge, **no se despliega nada**, y lo que está en git deja de coincidir con lo desplegado.

La solución tiene dos partes:

1. **Versiones inmutables.** `publicar-anidadas.ps1` calcula una versión a partir del contenido de las anidadas (un hash de 12 caracteres), las sube a `cloudformation/<version>/` y escribe esa versión en `deployment.yaml`. Al cambiar una anidada, cambia `deployment.yaml`, así que Git sync despliega. Cada versión queda en su carpeta: se sabe exactamente qué está desplegado y se puede volver atrás.
2. **El PR no pasa si se olvidó.** `.github/workflows/cloudformation.yml` ejecuta `verificar.sh` en cada PR. Falla si la versión no coincide con las anidadas, si las claves de `claves/` no coinciden con `deployment.yaml` o si `cfn-lint` encuentra errores. No necesita credenciales de AWS.

El mismo script copia las claves de `claves/*.pub` a `deployment.yaml` y fija la AMI de Amazon Linux 2023.

## Contraseñas: no están en ningún lado

`deployment.yaml` está en un repo público, así que no puede llevar contraseñas. La contraseña de la base de datos, el secreto JWT y la del administrador se **generan dentro del backend** cuando arranca. No están en git, ni en los parámetros del stack ni en el `UserData`, y no cuesta nada.

Para ver la contraseña del administrador, entra al backend por SSH:

```bash
sudo grep ADMIN_PASSWORD /etc/asistencia/backend.env
```

---

## 1. Preparación (una sola vez, A)

### 1.1 Publicar las plantillas anidadas

Usa el bucket del grupo (el del estado de Terraform), en la carpeta `cloudformation/`:

```powershell
cd D:\Diplomado-2026\infra-grupo
.\cloudformation\scripts\publicar-anidadas.ps1
git add cloudformation
git commit -m "CloudFormation: primera versión de las plantillas anidadas"
git push
```

El script escribe en `deployment.yaml` la versión, la AMI y las claves. B usa `-Profile grupo`.

### 1.2 Conectar Git sync

En la consola de AWS (región **us-east-2**):

1. **Developer Tools → Settings → Connections → Create connection → GitHub.** Autoriza el acceso a `jdguior06/infraestructura-aws-azure`.
2. **CloudFormation → Create stack → Sync from Git.**
   - Stack name: `asistencia-cfn`
   - Repository: `jdguior06/infraestructura-aws-azure`, branch `main`
   - **I am providing my own file**, ruta: `cloudformation/git-sync/deployment.yaml`
   - IAM role: deja que CloudFormation lo cree.
   - Activa **Enable comment on pull request**: CloudFormation comenta en cada PR qué recursos va a cambiar, que es el equivalente del `plan`.
3. Si Git sync abre un PR de inicialización, revísalo y haz merge.
4. Espera `CREATE_COMPLETE` (unos 5 minutos) y otros 5-10 minutos a que termine cloud-init.

Si un stack anidado falla con **Access Denied** al leer la plantilla de S3, al rol que usa CloudFormation le falta `s3:GetObject` sobre `arn:aws:s3:::tfstate-asistencia-859142233691/cloudformation/*`.

### 1.3 Proteger `main` (recomendado)

GitHub → Settings → Branches → regla para `main`: exigir PR y que pase el check **CloudFormation / verificar**. Así nadie despliega sin revisión ni con las anidadas desactualizadas.

---

## 2. Trabajo del día a día (cualquier integrante)

```powershell
git pull
git switch -c cambio-x
# editar plantillas/main.yaml, plantillas/anidadas/*.yaml o git-sync/deployment.yaml
.\cloudformation\scripts\publicar-anidadas.ps1    # solo si cambiaste algo en anidadas/ o claves/
git add cloudformation
git commit -m "..."
git push -u origin cambio-x
# abrir PR → revisar el comentario de CloudFormation y el check → merge
```

Si solo cambias `main.yaml` o un valor de `deployment.yaml` (por ejemplo `TipoInstanciaFrontend: t3.small`), no hace falta el script ni credenciales de AWS: basta con el PR.

## 3. Demostración colaborativa

| Paso | Quién | Qué hace | Qué demuestra |
| --- | --- | --- | --- |
| 1 | A | Conecta Git sync | El stack se crea desde GitHub, no desde una PC |
| 2 | B | PR: `TipoInstanciaFrontend: t3.small` en `deployment.yaml` | El comentario del PR muestra el cambio, y el merge lo despliega solo |
| 3 | A | PR: una etiqueta `Demo` en `frontend.yaml`, **sin** ejecutar el script | El check del PR falla: protege contra la anidada desactualizada |
| 4 | A | Ejecuta el script, sube `deployment.yaml` y hace merge | Ahora sí se despliega, en una carpeta de versión nueva |
| 5 | A y B | Merge de dos PRs seguidos | No corren a la vez: el segundo se aplica cuando termina el primero |
| 6 | Cualquiera | Un PR con un error que AWS solo detecta al aplicar (por ejemplo `PuertoBackend: "70000"`) | El despliegue falla y CloudFormation **vuelve solo** al estado anterior |
| 7 | Cualquiera | Consola → stack → **Events** / **Git sync** | Historial: cada commit, cada cambio y quién lo hizo |

## 4. Comandos útiles (lectura)

```powershell
# Salidas: URL, IPs, comandos SSH
aws cloudformation describe-stacks --stack-name asistencia-cfn --region us-east-2 --query "Stacks[0].Outputs" --output table

# Últimos eventos
aws cloudformation describe-stack-events --stack-name asistencia-cfn --region us-east-2 --max-items 15 --output table

# Detectar cambios hechos a mano en la consola (drift)
aws cloudformation detect-stack-drift --stack-name asistencia-cfn --region us-east-2
```

## 5. Lo que recrea servidores (y borra la base de datos)

| Cambio | Efecto |
| --- | --- |
| Etiquetas | se modifica, sin interrupción |
| `TipoInstancia*` | se detiene y reinicia el servidor |
| cloud-init (`UserData`), `ImagenAmi`, subred | **se reemplaza el servidor**: en el backend se pierde la base de datos |

La AMI está fijada en `deployment.yaml` a propósito: si la plantilla usara "la más reciente", cualquier despliegue después de una actualización de Amazon recrearía los servidores. Para actualizarla: `publicar-anidadas.ps1 -ActualizarAmi`.

## 6. Borrar todo

1. Consola → CloudFormation → `asistencia-cfn` → pestaña **Git sync** → **Disconnect**, para que un commit no lo vuelva a crear.
2. Borrar el stack:

   ```powershell
   aws cloudformation delete-stack --stack-name asistencia-cfn --region us-east-2
   ```

3. Opcional, borrar las plantillas publicadas: `aws s3 rm s3://tfstate-asistencia-859142233691/cloudformation/ --recursive`.

No borra el bucket ni el estado de Terraform, que están en otra carpeta.

## 7. Comparación con Terraform y Pulumi

| | Terraform / Pulumi | CloudFormation + Git sync |
| --- | --- | --- |
| Quién despliega | cada integrante desde su PC | AWS, al hacer merge a `main` |
| Estado | archivo en S3 / Blob | dentro de AWS, no se ve ni se toca |
| Bloqueo | lock file / lease | una operación por stack, en orden |
| Ver cambios antes | `plan` / `preview` | comentario de CloudFormation en el PR |
| Si falla a la mitad | queda a medias | rollback automático |
| Contraseñas | en el estado (cifradas en Pulumi) | generadas en la VM, no salen de ella |
| Módulos | `module` / funciones | stacks anidados en S3 |
| Credenciales de nube | todos los integrantes | solo quien publica las anidadas |
