# Infraestructura en grupo · Sistema de Control de Asistencia

Dos integrantes administran **la misma infraestructura** desde sus PCs. El código está en GitHub y el **estado**, en la nube, con **bloqueo** (un solo `apply` a la vez) y **versionado** (cada `apply` guarda una versión).

```
infra-grupo/
├── claves/              claves públicas SSH de cada integrante (*.pub)
├── aws/                 (azure/ tiene los mismos archivos)
│   ├── bootstrap/       crea el lugar del estado, una sola vez
│   │   ├── versions.tf
│   │   ├── variables.tf
│   │   ├── main.tf
│   │   └── outputs.tf
│   ├── versions.tf      versiones de Terraform/OpenTofu y del proveedor
│   ├── backend.tf       dónde vive el estado compartido
│   ├── providers.tf     conexión con la nube
│   ├── variables.tf     valores configurables
│   ├── locals.tf        valores calculados (claves SSH del grupo)
│   ├── red.tf           red, subred, IPs
│   ├── seguridad.tf     firewalls de frontend y backend
│   ├── servidores.tf    las dos máquinas
│   └── outputs.tf       IPs, URL y comandos SSH
```

Terraform lee juntos todos los `.tf` de una carpeta, así que el orden de los archivos no importa: dividirlos es solo para que el equipo encuentre las cosas rápido.

Funciona con Terraform y con OpenTofu: cambia `terraform` por `tofu`. **Todo el grupo usa la misma herramienta.**

Roles: **A** es el dueño de la cuenta compartida; **B** es el compañero.

---

## 0. Requisitos (cada integrante, en su PC)

| Herramienta | Instalación en Windows | Comprobar |
| --- | --- | --- |
| Terraform **u** OpenTofu (el mismo para todos) | `winget install Hashicorp.Terraform` · `winget install OpenTofu.Tofu` | `terraform -version` · `tofu -version` |
| Git | `winget install Git.Git` | `git --version` |
| AWS CLI | `winget install Amazon.AWSCLI` | `aws --version` |
| Azure CLI | `winget install Microsoft.AzureCLI` | `az version` |
| Cliente SSH | Viene con Windows 10/11 | `ssh -V` |

Abre una terminal nueva después de instalar, para que se reconozcan los comandos.

---

## 1. Preparación (una sola vez)

### 1.1 Claves SSH (cada integrante)

Cada uno genera su clave y sube **solo la pública** a `claves/`:

```powershell
ssh-keygen -t ed25519 -C "tu-nombre"          # Enter en todas las preguntas
copy $HOME\.ssh\id_ed25519.pub claves\diego.pub
```

Como el repositorio todavía no existe, B puede enviarle su `id_ed25519.pub` a A por chat o correo (la clave pública no es secreta) y A la guarda en `claves/`. Si ya tienes una clave en `$HOME\.ssh`, no generes otra: copia la que tienes. El paso a paso, con qué responder a cada pregunta, está en `claves/LEEME.md`.

Todas las claves deben estar en `claves/` **antes del primer `apply`**.

> Desde aquí hasta el final de la sección 1, los pasos los hace **A**, salvo donde se indica B.

### 1.2 Bootstrap del estado

**AWS**

```powershell
cd aws\bootstrap
terraform init
terraform apply
terraform output -raw bloque_backend
```

**Azure** (registrar antes el proveedor de almacenamiento)

```powershell
az provider register --namespace Microsoft.Storage
cd azure\bootstrap
terraform init
terraform apply -var="subscription_id=<ID-de-la-suscripción>"
terraform output -raw bloque_backend
```

Copia el bloque que muestra `bloque_backend` y **reemplaza** el bloque `backend` que está en `aws/backend.tf` o `azure/backend.tf`.

El estado del bootstrap queda en la PC de A (no se sube). El bucket y la Storage Account tienen `prevent_destroy`, para que nadie borre el estado del grupo por error.

### 1.3 Dar acceso a B

Regla: **cada integrante entra con su propia identidad**, a la misma cuenta. Nunca se comparte la contraseña ni las claves de acceso de A.

**AWS:** en la cuenta de A, IAM → Users → Create user (`integrante-b`) → política `AdministratorAccess` → Security credentials → Create access key (CLI). Es un usuario **nuevo**, solo para B; la cuenta propia de B no se usa. Entrega las claves a B por un medio privado.

B configura un perfil aparte, para no mezclarlo con su propia cuenta:

```powershell
aws configure --profile grupo
$env:AWS_PROFILE = "grupo"          # en cada terminal nueva
aws sts get-caller-identity         # debe mostrar la cuenta de A
```

**Azure:** Microsoft Entra ID → Usuarios → Nuevo usuario → **Invitar a un usuario externo** (el correo de la cuenta Microsoft de B). Luego, en la suscripción → **Control de acceso (IAM)** → Agregar asignación de roles → **Colaborador** → B.

B acepta la invitación del correo y entra con **su propia cuenta Microsoft** a la suscripción de A:

```powershell
az account show --query tenantId -o tsv     # A le pasa este valor a B
az login --tenant <tenant-id-de-A>
az account set --subscription <ID-de-la-suscripción>
```

### 1.4 Repositorio

A sube el proyecto a un repositorio **privado** en GitHub (incluido `.terraform.lock.hcl` después del primer `init`) y agrega a B como colaborador.

En Azure, cada uno crea `azure/terraform.tfvars` a partir del `.example`, con el mismo `subscription_id`.

---

## 2. Demostración

Todos los comandos se ejecutan **dentro de la carpeta de la nube** (`cd aws` o `cd azure`). B, en AWS, debe tener `$env:AWS_PROFILE = "grupo"` en esa terminal.

| Paso | Quién | Comandos | Qué demuestra |
| --- | --- | --- | --- |
| 1 | A | `terraform init` · `terraform apply` | Se crea la infraestructura y el estado se guarda en la nube |
| 2 | B | `git clone` · `terraform init` · `terraform plan` | **`No changes`**: B ve la infraestructura de A sin haberla creado |
| 3 | B | Edita el código · `terraform plan` · `terraform apply` · `git add` · `git commit` · `git push` | El plan muestra exactamente qué cambiará |
| 4 | A | `terraform plan` **sin** `git pull` | Terraform propone deshacer el cambio de B: el código de A está desactualizado |
| 5 | A | `git pull` · `terraform plan` | `No changes`: código y estado vuelven a coincidir |
| 6 | A y B | A: `terraform apply` y **no** responde `yes`. B: `terraform plan` | B recibe `Error acquiring the state lock`, con quién lo tiene y desde cuándo |
| 7 | Cualquiera | Ver versiones del estado (abajo) | Hay una versión por cada `apply` |

**Paso 3, cambios sugeridos:**

| Cambio | Archivo | Símbolo en el plan |
| --- | --- | --- |
| Agregar una etiqueta en `tags` de un servidor (ej. `Demo = "cambio-b"`) | `servidores.tf` | `~` se modifica |
| Agregar una regla de seguridad (ej. puerto 8080 en el frontend) | `seguridad.tf` | `+` se crea |
| Cambiar `tipo_instancia_frontend` / `tamano_frontend` | `variables.tf` | `~` se reinicia el servidor |

**Paso 6:** mientras A está en la pregunta `Enter a value:`, el bloqueo sigue tomado. Al responder `no`, se libera.

**Paso 7, ver versiones del estado**

- AWS: consola S3 → bucket → `aws/terraform.tfstate` → pestaña **Versiones**.

  ```powershell
  aws s3api list-object-versions --bucket <bucket> --prefix aws/terraform.tfstate --query "Versions[].{Version:VersionId,Fecha:LastModified,Actual:IsLatest}" --output table
  ```

- Azure: Storage Account → Contenedores → `tfstate` → `azure/terraform.tfstate` → pestaña **Versiones**.

**Entrar a los servidores** (cualquier integrante, con su propia clave):

```powershell
terraform output ssh_frontend
terraform output ssh_backend
```

Copia el comando que aparece y ejecútalo. La primera vez responde `yes` a la pregunta de confianza. El usuario es `ec2-user` en AWS y `azureuser` en Azure.

---

## 3. Reglas del equipo

1. `git pull` antes de cada `plan`.
2. Revisar el `plan` antes de cada `apply`.
3. Nunca editar ni borrar a mano el archivo de estado.
4. Si un `apply` se corta y el bloqueo queda tomado, solo quien lo tenía usa `terraform force-unlock <ID>`, después de avisar al grupo.
5. Al terminar la sesión, `terraform destroy` en `aws/` y `azure/` (no en `bootstrap/`).

## 4. Seguridad de esta práctica

- SSH está abierto a cualquier IP (`ssh_permitido`) para simplificar. Los servidores solo aceptan clave SSH, no contraseña. Para restringirlo, cambia `ssh_permitido` a una IP con `/32`.
- La API (puerto 3000) sigue aceptando solo tráfico del frontend, y PostgreSQL no está expuesto.

## 5. Al terminar la materia

Para borrar también el estado: en `bootstrap/main.tf` cambia `prevent_destroy = true` a `false` (en AWS, agrega también `force_destroy = true` al bucket, porque tiene versiones), ejecuta `terraform apply` y luego `terraform destroy`.
