#!/usr/bin/env bash
# Revisión automática de cada PR (la ejecuta .github/workflows/cloudformation.yml).
# No necesita credenciales de AWS. Falla si:
#   - alguien cambió una plantilla anidada y no ejecutó publicar-anidadas.ps1,
#   - las claves de claves/ no coinciden con las de deployment.yaml,
#   - falta la AMI,
#   - cfn-lint encuentra errores en las plantillas.
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"

deployment=cloudformation/git-sync/deployment.yaml
errores=0

valor() { # lee un parámetro de deployment.yaml (sin comillas)
  grep -E "^\s*$1\s*:" "$deployment" | head -1 | sed -E "s/^\s*$1\s*:\s*//; s/^\"//; s/\"\s*$//; s/\r$//"
}

# 1. Versión de las plantillas anidadas (mismo cálculo que publicar-anidadas.ps1).
esperada=$(
  for f in $(printf '%s\n' cloudformation/plantillas/anidadas/*.yaml | LC_ALL=C sort); do
    echo "$(basename "$f") $(git hash-object -- "$f")"
  done | sha256sum | cut -c1-12
)
actual=$(valor VersionPlantillas)
if [ "$esperada" != "$actual" ]; then
  echo "::error::Las plantillas anidadas cambiaron (versión $esperada) pero deployment.yaml dice $actual. Ejecuta scripts/publicar-anidadas.ps1 y sube deployment.yaml."
  errores=1
else
  echo "OK  versión de plantillas anidadas: $actual"
fi

# 2. Claves SSH iguales a las de claves/.
claves=$(
  for f in $(printf '%s\n' claves/*.pub | LC_ALL=C sort); do
    tr -d '\r' < "$f" | sed -E 's/[[:space:]]+$//' | tr -d '\n'
    echo
  done | paste -sd, -
)
if [ "$claves" != "$(valor ClavesSsh)" ]; then
  echo "::error::ClavesSsh de deployment.yaml no coincide con claves/*.pub. Ejecuta scripts/publicar-anidadas.ps1."
  errores=1
else
  echo "OK  claves SSH: $(ls claves/*.pub | wc -l) archivo(s)"
fi

# 3. AMI definida.
ami=$(valor ImagenAmi)
if ! [[ "$ami" =~ ^ami-[0-9a-f]+$ ]]; then
  echo "::error::ImagenAmi no es una AMI válida ('$ami'). Ejecuta scripts/publicar-anidadas.ps1."
  errores=1
else
  echo "OK  AMI: $ami"
fi

# 4. cfn-lint (solo errores bloquean; los avisos se muestran).
if cfn-lint --regions us-east-2 --non-zero-exit-code error -- \
    cloudformation/plantillas/main.yaml cloudformation/plantillas/anidadas/*.yaml; then
  echo "OK  cfn-lint"
else
  errores=1
fi

exit $errores
