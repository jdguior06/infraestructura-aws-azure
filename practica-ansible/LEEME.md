# Práctica: Terraform crea, Ansible configura

Tres servidores en AWS y en Azure. **Terraform** los crea vacíos (solo con las claves SSH) y **Ansible** los configura: PostgreSQL en su propio servidor, la API NestJS y el frontend con Nginx. Ya no se usa cloud-init para desplegar la app.

```
              internet
                 │ 80 / 443
          ┌──────▼──────┐   3000    ┌─────────────┐   5432    ┌─────────────┐
          │  frontend   │ ────────► │   backend   │ ────────► │    base     │
          │ Nginx+React │           │   NestJS    │           │ PostgreSQL  │
          │  10.0.1.20  │           │  10.0.1.10  │           │  10.0.1.30  │
          └─────────────┘           └─────────────┘           └─────────────┘
                 ▲                         ▲                         ▲
                 └──────── SSH (22): Ansible desde tu PC ────────────┘
```

| Servidor | Desde internet | Desde la red interna |
| --- | --- | --- |
| frontend | 80, 443, 22 | — |
| backend | solo 22 | 3000 **solo desde el frontend** |
| base | solo 22 | 5432 **solo desde el backend** |

Además del firewall de la nube, PostgreSQL tiene su propia regla (`pg_hba.conf`): solo acepta al backend, solo a la base `modulo2`, solo al usuario `asistencia` y siempre con contraseña.

```
practica-ansible/
├── aws/                     Terraform AWS  (estado: S3, clave practica-ansible/aws/)
├── azure/                   Terraform Azure (estado: Blob, clave practica-ansible/azure/)
│   └── ansible.tf           escribe el inventario de Ansible con las IPs
└── ansible/
    ├── ansible.cfg          configuración (clave SSH, Vault, pipelining)
    ├── site.yml             el playbook: base → backend → frontend
    ├── inventarios/         inventario.tftpl (plantilla) · aws.ini / azure.ini (los genera Terraform)
    ├── group_vars/all/      vars.yml (valores) · vault.yml (secretos cifrados)
    └── roles/
        ├── comun/           paquetes básicos
        ├── postgresql/      PostgreSQL en la red privada, usuario y base
        ├── nodejs/          Node 22 (NodeSource) y swap si hay poca RAM
        ├── codigo/          usuario "asistencia" y git clone
        ├── backend/         .env, compilar, migraciones, servicio systemd
        └── frontend/        compilar, Nginx con proxy a /api
```

Los roles detectan el sistema: los mismos archivos sirven para Amazon Linux (AWS, `dnf`) y Ubuntu (Azure, `apt`).

---

## 0. Preparar el equipo (una vez por integrante)

**Terraform** se sigue usando desde PowerShell, como siempre. **Ansible no funciona en Windows**: se usa desde **WSL** (Ubuntu dentro de Windows). En Ubuntu nativo, salta al punto 0.3.

### 0.1 Instalar WSL (PowerShell como administrador)

```powershell
wsl --install -d Ubuntu-24.04
```

Reinicia si lo pide, abre **Ubuntu** desde el menú Inicio y crea tu usuario.

### 0.2 Permisos de Linux en el disco D: (dentro de WSL)

Sin esto, WSL ve todos los archivos de `D:` como "escribibles por todos" y Ansible **ignora** el `ansible.cfg` por seguridad.

```bash
sudo tee /etc/wsl.conf > /dev/null <<'EOF'
[automount]
options = "metadata,umask=22,fmask=11"
EOF
```

Luego, en PowerShell: `wsl --shutdown`, y vuelve a abrir Ubuntu.

### 0.3 Ansible, clave SSH y contraseña de Vault (dentro de WSL)

```bash
sudo apt update && sudo apt install -y ansible
ansible --version

# Tu clave privada SSH (la misma que usas en Windows), con permisos estrictos
mkdir -p ~/.ssh
cp /mnt/c/Users/<tu-usuario-de-windows>/.ssh/id_ed25519 ~/.ssh/
chmod 600 ~/.ssh/id_ed25519

# Contraseña de Ansible Vault: la MISMA para todo el grupo (se comparte en privado)
echo 'la-contrasena-de-vault-del-grupo' > ~/.vault_asistencia
chmod 600 ~/.vault_asistencia
```

### 0.4 Secretos de la app (solo A, una vez)

```bash
cd /mnt/d/Diplomado-2026/infra-grupo/practica-ansible/ansible
cp group_vars/all/vault.yml.ejemplo group_vars/all/vault.yml
nano group_vars/all/vault.yml          # cambia los 3 valores: solo letras y números, 12+ caracteres
ansible-vault encrypt group_vars/all/vault.yml
head -1 group_vars/all/vault.yml       # debe decir $ANSIBLE_VAULT;1.1;AES256
```

Sube `vault.yml` **solo cuando esté cifrado**. Sin la contraseña de Vault nadie puede leerlo.

```bash
ansible-vault view group_vars/all/vault.yml   # ver los secretos
ansible-vault edit group_vars/all/vault.yml   # cambiarlos
```

---

## 1. Crear la infraestructura (PowerShell)

```powershell
cd D:\Diplomado-2026\infra-grupo\practica-ansible\aws
terraform init
terraform plan        # 3 servidores, 3 security groups, Elastic IP, inventario...
terraform apply
```

Para Azure es lo mismo en `practica-ansible\azure`, pero antes copia tu `terraform.tfvars` (con `subscription_id`) desde la carpeta `azure\` de la práctica anterior.

El `apply` escribe `practica-ansible/ansible/inventarios/aws.ini` (o `azure.ini`) con las IPs. Ese archivo **no se sube a git**. Si tu compañero creó la infraestructura, tú ejecuta `terraform apply` igual: el plan solo muestra `+ local_file` (tu copia del inventario) y no toca los servidores.

Sube los `.terraform.lock.hcl` nuevos al repo.

## 2. Configurar con Ansible (WSL)

```bash
cd /mnt/d/Diplomado-2026/infra-grupo/practica-ansible/ansible

ansible all -i inventarios/aws.ini -m ping              # los 3 deben responder "pong"
ansible-playbook -i inventarios/aws.ini site.yml        # 10-15 min la primera vez
```

Al final muestra `Listo: http://<ip>`. Entra con `admin@example.com` y la contraseña de `vault_admin_password` (`ansible-vault view group_vars/all/vault.yml`).

Para Azure: `-i inventarios/azure.ini`.

## 3. Lo que se puede mostrar en la defensa

| Qué | Comando (en WSL, dentro de `ansible/`) | Qué se ve |
| --- | --- | --- |
| Idempotencia | `ansible-playbook -i inventarios/aws.ini site.yml` (otra vez) | `changed=0` en todos: no recompila ni reinicia nada |
| Ver antes de cambiar | `ansible-playbook -i inventarios/aws.ini site.yml --check --diff` | Qué cambiaría, sin tocar nada (como `terraform plan`) |
| Actualizar la app | Commit nuevo en el repo de la app → volver a ejecutar `site.yml` | Solo `git`, `npm ci`, `build` y reinicio: lo que cloud-init no podía hacer |
| Base aislada | `ansible vm-frontend -i inventarios/aws.ini -m shell -a "timeout 3 bash -c '</dev/tcp/10.0.1.30/5432' && echo ABIERTO \|\| echo CERRADO"` | `CERRADO`: el frontend no llega a la base |
| …pero el backend sí | Igual con `vm-backend` | `ABIERTO` |
| Estado de los servicios | `ansible vm-backend -i inventarios/aws.ini -b -m shell -a "systemctl status asistencia-api --no-pager"` | `active (running)` |
| Un solo servidor | `ansible-playbook -i inventarios/aws.ini site.yml --limit vm-frontend` | Solo configura el frontend |
| Secretos | `cat group_vars/all/vault.yml` | Texto cifrado: se puede subir a git |

## 4. Trabajo en grupo

- **Terraform:** igual que antes. Estado remoto con bloqueo, en otra clave del mismo bucket o Storage Account, así no choca con las prácticas anteriores.
- **Ansible no tiene estado.** En cada ejecución revisa cómo están los servidores y cambia solo lo que no coincide con el código. No hay archivo que bloquear: lo que se coordina es **git**. Antes de ejecutar, `git pull`.
- **Secretos:** `vault.yml` cifrado en el repo y una sola contraseña de Vault para el grupo, igual que la frase de Pulumi.
- Si dos personas ejecutan el playbook a la vez sobre los mismos servidores, pueden chocar (por ejemplo, dos `npm ci` al mismo tiempo). Avísense antes de ejecutar, o que lo haga uno solo.

## 5. Si algo falla

| Error | Causa y solución |
| --- | --- |
| `Ansible is being run in a world writable directory` | Falta el paso 0.2 (`/etc/wsl.conf` y `wsl --shutdown`) |
| `UNPROTECTED PRIVATE KEY FILE` | `chmod 600 ~/.ssh/id_ed25519` (y que la clave esté en `~/.ssh` de WSL, no en `/mnt/c`) |
| `The vault password file ... was not found` | Falta `~/.vault_asistencia` (paso 0.3) |
| `Permission denied (publickey)` | Tu `.pub` no estaba en `claves/` cuando se crearon los servidores |
| `UNREACHABLE` justo después del `apply` | Los servidores están arrancando: espera un minuto y vuelve a intentar |
| Falla `npm run build` por memoria | Revisa que se creó el swap (`free -h` en el servidor) |
| `Comprobar que Nginx llega a la API` falla (502) | El backend no responde: `journalctl -u asistencia-api -n 50` en `vm-backend` |
| Las migraciones fallan con `ECONNREFUSED` o `timeout` | El backend no llega a la base: revisa el firewall y que PostgreSQL esté activo en `vm-base` |
| En AWS cambió la IP del backend o de la base | Pasa si se detienen. `terraform apply` vuelve a escribir el inventario |

## 6. Borrar todo

```powershell
cd D:\Diplomado-2026\infra-grupo\practica-ansible\aws;   terraform destroy
cd ..\azure;                                             terraform destroy
```

Son 3 servidores y 3 IPs públicas por nube: no los dejen encendidos sin usar.

## 7. cloud-init vs Ansible

| | cloud-init (práctica anterior) | Ansible (esta práctica) |
| --- | --- | --- |
| Cuándo corre | una vez, en el primer arranque | cada vez que se ejecuta |
| Actualizar la app | recrear el servidor | volver a ejecutar el playbook |
| Ver cambios antes | no | `--check --diff` |
| Lo entrega | la herramienta de IaC (`user_data`) | SSH desde tu PC |
| Estado | no tiene | no tiene: revisa el servidor cada vez |
| Organización | un script por servidor | roles reutilizables, con variantes por sistema |
| Secretos | en el estado de Terraform / Pulumi | Ansible Vault, cifrados en git |
