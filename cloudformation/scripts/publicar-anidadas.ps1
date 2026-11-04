# Publica las plantillas anidadas en S3 y actualiza git-sync/deployment.yaml.
#
# Por qué existe: Git sync solo vigila main.yaml y deployment.yaml, y las plantillas
# anidadas se leen desde S3. Este script sube cada versión a una carpeta propia
# (cloudformation/<version>/) y escribe esa versión en deployment.yaml. Así, cambiar
# una plantilla anidada también cambia deployment.yaml, y Git sync la despliega.
#
# La versión es un hash del contenido de plantillas/anidadas/: si no cambian, no cambia.
#
# Uso (desde la raíz del repo o desde cloudformation/):
#   .\cloudformation\scripts\publicar-anidadas.ps1
#   .\cloudformation\scripts\publicar-anidadas.ps1 -Profile grupo
#   .\cloudformation\scripts\publicar-anidadas.ps1 -ActualizarAmi   # usa la AMI más reciente

param(
    [string]$Region = 'us-east-2',
    [string]$Profile = '',
    [switch]$ActualizarAmi
)
$ErrorActionPreference = 'Stop'

$raizCfn    = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
$raizRepo   = (Resolve-Path (Join-Path $raizCfn '..')).Path
$anidadas   = Join-Path $raizCfn 'plantillas\anidadas'
$deployment = Join-Path $raizCfn 'git-sync\deployment.yaml'
$awsPerfil  = @()
if ($Profile) { $awsPerfil = @('--profile', $Profile) }

function Escribir-Utf8SinBom([string]$ruta, [string]$texto) {
    [System.IO.File]::WriteAllText($ruta, $texto, (New-Object System.Text.UTF8Encoding $false))
}

# Orden ordinal (como "LC_ALL=C sort" en verificar.sh), para que la versión salga igual en Windows y Linux.
function Ordenar-PorNombre($elementos) {
    $lista = @($elementos)
    $nombres = [string[]]($lista | ForEach-Object { $_.Name })
    [Array]::Sort($nombres, $lista, [StringComparer]::Ordinal)
    return $lista
}

function Cambiar-Parametro([string]$texto, [string]$nombre, [string]$valor) {
    $patron = "(?m)^(\s*$nombre\s*:\s*)[^\r\n]*"
    if ($texto -notmatch $patron) { throw "No encontré '$nombre' en deployment.yaml" }
    return [regex]::Replace($texto, $patron, { param($m) $m.Groups[1].Value + '"' + $valor + '"' })
}

# 1. Versión = hash de "archivo hash-git" de cada plantilla anidada (igual que verificar.sh).
$archivos = Ordenar-PorNombre (Get-ChildItem $anidadas -Filter *.yaml)
$lista = ''
foreach ($archivo in $archivos) {
    $hashGit = (git -C $raizRepo hash-object -- $archivo.FullName).Trim()
    $lista += "$($archivo.Name) $hashGit`n"
}
$sha = [System.Security.Cryptography.SHA256]::Create()
$bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($lista))
$version = ([System.BitConverter]::ToString($bytes) -replace '-', '').ToLower().Substring(0, 12)
Write-Host "Versión de las plantillas anidadas: $version"

# 2. Bucket: el que dice deployment.yaml.
$texto = [System.IO.File]::ReadAllText($deployment)
if ($texto -notmatch '(?m)^\s*BucketPlantillas\s*:\s*"?([^"\r\n]+)"?') { throw 'Falta BucketPlantillas en deployment.yaml' }
$bucket = $Matches[1].Trim()

# 3. Subir a s3://<bucket>/cloudformation/<version>/
foreach ($archivo in $archivos) {
    $destino = "s3://$bucket/cloudformation/$version/$($archivo.Name)"
    Write-Host "Subiendo $($archivo.Name) -> $destino"
    aws s3 cp $archivo.FullName $destino --region $Region --only-show-errors @awsPerfil
    if ($LASTEXITCODE -ne 0) { throw "Falló la subida de $($archivo.Name)" }
}

# 4. Actualizar deployment.yaml: versión, claves SSH (de claves/) y AMI.
$texto = Cambiar-Parametro $texto 'VersionPlantillas' $version

$claves = Ordenar-PorNombre (Get-ChildItem (Join-Path $raizRepo 'claves') -Filter *.pub) |
    ForEach-Object { ([System.IO.File]::ReadAllText($_.FullName)).Trim() }
if (-not $claves) { throw 'No hay claves .pub en claves/' }
$texto = Cambiar-Parametro $texto 'ClavesSsh' ($claves -join ',')

if ($ActualizarAmi -or $texto -match 'REEMPLAZAR_AMI') {
    $ami = (aws ssm get-parameter --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 `
        --query Parameter.Value --output text --region $Region @awsPerfil).Trim()
    if ($LASTEXITCODE -ne 0 -or -not $ami) { throw 'No pude leer la AMI de Amazon Linux 2023' }
    Write-Host "AMI de Amazon Linux 2023: $ami (cambiarla recrea los servidores)"
    $texto = Cambiar-Parametro $texto 'ImagenAmi' $ami
}

Escribir-Utf8SinBom $deployment $texto

Write-Host ''
Write-Host 'Listo. Ahora sube los cambios para que Git sync los despliegue:'
Write-Host '  git add cloudformation'
Write-Host '  git commit -m "..."'
Write-Host '  git push      (o abre un PR hacia main)'
