#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SITE_DIR=${SCRIPT_DIR}/../site

if [[ ! -f ${SITE_DIR}/dist/index.html ]]; then
  echo "Compilando el sitio web."
  apt-get update
  apt-get install -y ca-certificates curl
  NODE_MAJOR=0
  if command -v node >/dev/null 2>&1; then
    NODE_MAJOR=$(node --version | sed -E 's/^v([0-9]+).*/\1/')
  fi
  if (( NODE_MAJOR < 22 )); then
    NODE_SETUP=$(mktemp)
    trap 'rm -f "${NODE_SETUP}"' EXIT
    curl --fail --silent --show-error --location https://deb.nodesource.com/setup_22.x --output "${NODE_SETUP}"
    bash "${NODE_SETUP}"
    apt-get install -y nodejs
  fi
  cd "${SITE_DIR}"
  npm ci
  npm run build
fi

if ! command -v apache2ctl >/dev/null 2>&1 || [[ ! -L /etc/apache2/sites-enabled/aerolinea.conf ]]; then
  echo "Apache no está configurado. Ejecutando instalación inicial."
  "${SCRIPT_DIR}/install.sh"
else
  apache2ctl configtest
  systemctl enable apache2
  systemctl restart apache2
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "Sitio web disponible en el puerto 80."
