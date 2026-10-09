#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
DOMAIN=${DOMAIN:-aerolinea.redes.test}

if ! command -v named-checkconf >/dev/null 2>&1 || [[ ! -f /etc/bind/zones/db.${DOMAIN} ]]; then
  echo "BIND9 no está configurado. Ejecutando instalación inicial."
  "${SCRIPT_DIR}/install.sh"
else
  named-checkconf
  named-checkzone "${DOMAIN}" "/etc/bind/zones/db.${DOMAIN}"
  systemctl enable named
  systemctl restart named
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "DNS disponible en el puerto 53."
