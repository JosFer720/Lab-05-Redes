#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)

if ! command -v slapd >/dev/null 2>&1 || [[ -n ${USERS_FILE:-} ]]; then
  echo "Configurando OpenLDAP con LDAP_ADMIN_PASSWORD y USERS_FILE."
  "${SCRIPT_DIR}/install.sh"
else
  systemctl enable slapd
  systemctl restart slapd
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "LDAP disponible en el puerto 389."
echo "Datos de conexión y usuarios: docs/openldap-en-mac.md."
