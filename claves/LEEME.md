# Claves públicas SSH del grupo

Cada integrante genera **su propia** clave SSH y deja aquí **solo la parte pública**, con su nombre.

## 1. Revisar si ya tienes una clave

```powershell
dir $HOME\.ssh
```

Si ya existen `id_ed25519` e `id_ed25519.pub`, sáltate el paso 2: usa esa misma clave.

## 2. Generar la clave (una sola vez)

En **PowerShell** (Windows 10/11 ya trae SSH; si `ssh -V` no responde, actívalo en Configuración → Sistema → Características opcionales → Cliente OpenSSH):

```powershell
ssh-keygen -t ed25519 -C "tu-nombre"
```

En **Linux o macOS**, el mismo comando en la terminal.

Responde a las preguntas:

| Pregunta | Qué hacer |
| --- | --- |
| `Enter file in which to save the key` | **Enter** (acepta la ruta por defecto) |
| `Enter passphrase` | Enter para dejarla vacía, o escribe una contraseña para la clave |
| `Enter same passphrase again` | Repite lo anterior |
| `Overwrite (y/n)?` (solo si ya tenías una) | **n**, y usa la que ya tienes |

Se crean dos archivos en tu carpeta `.ssh`:

| Archivo | Qué es | Qué hacer |
| --- | --- | --- |
| `id_ed25519` | Clave **privada** | Se queda en tu PC. **Nunca** se comparte ni se sube |
| `id_ed25519.pub` | Clave **pública** | Es la que va en esta carpeta |

## 3. Agregar tu clave pública al repositorio

Desde la raíz del repositorio:

```powershell
copy $HOME\.ssh\id_ed25519.pub claves\diego.pub
git add claves\diego.pub
git commit -m "Agrega clave SSH de Diego"
git push
```

En Linux o macOS: `cp ~/.ssh/id_ed25519.pub claves/diego.pub`.

## Reglas

- Solo archivos `.pub`. El `.gitignore` bloquea cualquier otro archivo de esta carpeta, por si alguien copia la privada por error.
- Todas las claves deben estar aquí **antes del primer `apply`**. En Azure, agregar una clave después recrea las máquinas; en AWS, solo se aplica a servidores nuevos.
- Cada integrante entra a los servidores con **su propia** clave privada: `terraform output ssh_frontend` muestra el comando.
