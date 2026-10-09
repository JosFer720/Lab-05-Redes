#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
BASE_DN=${BASE_DN:-dc=aerolinea,dc=redes,dc=test}
LDAP_ADMIN_PASSWORD=${LDAP_ADMIN_PASSWORD:-AdminLDAP}
LDAP_TEST_USER=${LDAP_TEST_USER:-nery}
LDAP_TEST_PASSWORD=${LDAP_TEST_PASSWORD:-NeryLab5}
USERS_FILE=${USERS_FILE:-}
TEMP_USERS_FILE=

if [[ -z ${USERS_FILE} ]]; then
  TEMP_USERS_FILE=$(mktemp)
  trap 'rm -f "${TEMP_USERS_FILE}"' EXIT
  cat > "${TEMP_USERS_FILE}" <<'EOF'
ian	Ian Cumes	Cumes	ian@aerolinea.redes.test	IanLab5
javier	Javier Valladares	Valladares	javier@aerolinea.redes.test	JavierLab5
fernando	Fernando Ruiz	Ruiz	fernando@aerolinea.redes.test	FernandoLab5
nery	Nery Molina	Molina	nery@aerolinea.redes.test	NeryLab5
hugo	Hugo Barillas	Barillas	hugo@aerolinea.redes.test	HugoLab5
milton	Milton Polanco	Polanco	milton@aerolinea.redes.test	MiltonLab5
guest	Usuario Invitado	Invitado	guest@aerolinea.redes.test	GuestLab5
EOF
  USERS_FILE=${TEMP_USERS_FILE}
fi
export BASE_DN LDAP_ADMIN_PASSWORD LDAP_TEST_USER LDAP_TEST_PASSWORD USERS_FILE

if ! command -v slapd >/dev/null 2>&1 ||
   ! ldapsearch -x -LLL -H ldap://127.0.0.1 -b "uid=guest,ou=People,${BASE_DN}" -s base dn >/dev/null 2>&1; then
  echo "OpenLDAP no está listo. Ejecutando configuración inicial."
  if command -v slapd >/dev/null 2>&1 &&
     ! ldapsearch -x -LLL -H ldap://127.0.0.1 -b "ou=People,${BASE_DN}" -s base dn >/dev/null 2>&1; then
    RECONFIGURE_LDAP=${RECONFIGURE_LDAP:-1}
    export RECONFIGURE_LDAP
  fi
  "${SCRIPT_DIR}/install.sh"
else
  systemctl enable slapd
  systemctl restart slapd
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "LDAP disponible en el puerto 389."
echo "Usuarios disponibles: ian, javier, fernando, nery, hugo, milton y guest."
echo "Las credenciales están documentadas en shared/lab.example.env."
