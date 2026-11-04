# Pulumi · la misma infraestructura en TypeScript

La misma arquitectura de `aws/` y `azure/` (Terraform), escrita con Pulumi: red, firewalls de frontend y backend, y dos servidores que se despliegan solos con los YAML de `cloud-init/`.

```
pulumi/
├── comun/cloud-init.ts   lee claves/ y prepara los YAML de cloud-init/ (lo usan los dos proyectos)
├── aws/                  proyecto asistencia-aws   → estado en S3
│   ├── Pulumi.yaml       backend, valores por defecto
│   ├── index.ts          los recursos
│   ├── package.json      versiones de los paquetes
│   └── tsconfig.json
└── azure/                proyecto asistencia-azure → estado en Azure Blob
    └── (los mismos archivos)
```

Todo es gratis: el CLI de Pulumi es open source y el estado vive en el bucket y el Storage Account del grupo (backend DIY), no en Pulumi Cloud.

Los recursos usan el prefijo `asistencia-pulumi`, distinto del de Terraform, para que los nombres no choquen. Aun así, **una herramienta a la vez**: haz `terraform destroy` antes de `pulumi up` para no pagar dos infraestructuras.

---

## 0. Requisitos (cada integrante)

| Herramienta | Instalación | Comprobar |
| --- | --- | --- |
| Pulumi | `winget install pulumi` | `pulumi version` |
| Node.js 22 | `winget install OpenJS.NodeJS.LTS` | `node -v` |
| AWS CLI / Azure CLI | los mismos de Terraform | `aws sts get-caller-identity` · `az account show` |

**No hagas `pulumi login`.** El backend está escrito en cada `Pulumi.yaml`. Si ya lo hiciste, `pulumi logout`.

## 1. Preparación (una sola vez)

### 1.1 Frase de cifrado del grupo

Pulumi cifra los secretos (contraseñas, outputs secretos) con una frase. **Todos usan la misma.** Se comparte por un medio privado, nunca en el repo.

```powershell
$env:PULUMI_CONFIG_PASSPHRASE = "la-frase-del-grupo"   # en cada terminal nueva
```

### 1.2 Permisos

- **AWS:** los mismos de Terraform. B usa `$env:AWS_PROFILE = "grupo"`.
- **Azure:** Pulumi lee el estado con tu `az login`, y para eso el rol **Colaborador no alcanza**. A asigna a cada integrante (incluido él mismo) el rol **Storage Blob Data Contributor**:

  ```powershell
  $cuenta = az storage account show -n sttfstate8f5a458c32 -g rg-tfstate-asistencia --query id -o tsv
  az role assignment create --role "Storage Blob Data Contributor" --assignee <correo> --scope $cuenta
  ```

  El permiso puede tardar unos minutos. Cada uno elige la suscripción del grupo: `az account set --subscription <ID>`.

### 1.3 Crear el stack (solo A, una vez por nube)

```powershell
cd pulumi\aws        # luego lo mismo en pulumi\azure
npm install
pulumi stack init dev
```

Se crea `Pulumi.dev.yaml` con la `encryptionsalt`. **Súbelo al repo** (junto con `package-lock.json`): sin él, B no puede leer los secretos.

```powershell
git add pulumi
git commit -m "Crea stacks dev de Pulumi"
git push
```

### 1.4 B se une

```powershell
git pull
cd pulumi\aws
npm install
pulumi stack select dev
```

---

## 2. Comandos

| Terraform | Pulumi | Qué hace |
| --- | --- | --- |
| `terraform init` | `npm install` | prepara el proyecto |
| `terraform plan` | `pulumi preview` | muestra qué cambiará |
| `terraform apply` | `pulumi up` | aplica (pregunta antes) |
| `terraform output` | `pulumi stack output` | IPs, URL, comandos SSH |
| `terraform output -raw admin_password` | `pulumi stack output adminContrasena --show-secrets` | contraseña del administrador |
| `terraform force-unlock <ID>` | `pulumi cancel` | libera un bloqueo trabado |
| versiones en S3/Blob | `pulumi stack history` | una entrada por cada `up` |
| `terraform destroy` | `pulumi destroy` | borra todo |
| variables | `pulumi config set <clave> <valor>` | cambia un valor del stack (ej. `tipoInstanciaFrontend t3.small`) |

Símbolos del preview: `+` se crea, `~` se modifica, `-` se borra, `+-` se reemplaza.

## 3. Demostración colaborativa

La misma de Terraform. Todos los comandos dentro de `pulumi\aws` o `pulumi\azure`, con la frase definida.

| Paso | Quién | Comandos | Qué demuestra |
| --- | --- | --- | --- |
| 1 | A | `pulumi up` | Se crea todo y el estado se guarda en la nube |
| 2 | B | `git pull` · `pulumi stack select dev` · `pulumi preview` | Sin cambios: B ve lo que creó A |
| 3 | B | Edita `index.ts` · `pulumi up` · `git push` | El preview muestra el cambio exacto |
| 4 | A | `pulumi preview` **sin** `git pull` | Pulumi propone deshacer el cambio de B |
| 5 | A | `git pull` · `pulumi preview` | Sin cambios otra vez |
| 6 | A y B | A: `pulumi up` y se queda en la pregunta. B: `pulumi preview` | B recibe el error de stack bloqueado |
| 7 | Cualquiera | `pulumi stack history` | Una entrada por cada `up`, con quién y cuándo |

**Cambios sugeridos para el paso 3:**

- Una etiqueta en un servidor: en `tags` agrega `Demo: "cambio-b"` → `~`
- Una regla nueva: en AWS agrega `["app", 8080, "0.0.0.0/0"]` a `reglasFrontend` → `+`
- El tamaño: `pulumi config set tipoInstanciaFrontend t3.small` → `~`, el servidor se reinicia. Este cambio queda en `Pulumi.dev.yaml`, así que también se sube con git.

## 4. Ver la app

cloud-init sigue trabajando 5-10 minutos después de `pulumi up`. Luego:

```powershell
pulumi stack output urlApp
pulumi stack output adminCorreo
pulumi stack output adminContrasena --show-secrets
```

Si no carga, entra con `pulumi stack output sshBackend` (y `sshFrontend`) y revisa `cloud-init status --wait` y `sudo tail -n 50 /var/log/cloud-init-output.log`. Detalles en `cloud-init/LEEME.md`.

## 5. Diferencias con Terraform que vale la pena contar

- **Lenguaje real:** los recursos repetidos se arman con un `for` o una función (`servidor()` en Azure), sin `count` ni `dynamic`.
- **Secretos cifrados:** las contraseñas de `random` y el `userData` aparecen como `[secret]` en el estado y el preview. En Terraform se ocultan en pantalla, pero en el estado quedan en texto plano.
- **Nombres:** si no se pone un nombre, Pulumi agrega un sufijo aleatorio (`vpc-a1b2c3`). Aquí se fijaron los nombres para que coincidan con los de Terraform.
- **Recreación explícita:** en Azure se usa `replaceOnChanges: ["osProfile"]` para que un cambio en cloud-init o en las claves recree la VM, como hace Terraform con `custom_data`.
