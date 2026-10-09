#!/usr/bin/env bash
# Cambia la IP de uno o varios registros A de la zona, sube el serial, valida
# con named-checkzone, regenera la tabla de resolución y recarga BIND.
#
#   ./scripts/set-ips.sh ldap=192.168.1.21 www=192.168.1.22
#   ./scripts/set-ips.sh ns1=10.0.0.5 ldap=10.0.0.6 www=10.0.0.7 mail=10.0.0.8 ftp=10.0.0.9
#
# DEPLOY=0 solo edita el archivo del repositorio, sin desplegar en /etc/bind.
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
DEPLOY=${DEPLOY:-1}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZONE_FILE=${ZONE_FILE:-${SCRIPT_DIR}/../zones/db.${DOMAIN}}

declare -A ROLE=([ns1]='BIND9' [ldap]='OpenLDAP' [www]='Apache' [mail]='Postfix + Dovecot' [ftp]='vsftpd')

usage() {
  cat >&2 <<'EOF'
Uso: set-ips.sh nombre=IP [nombre=IP ...]
Nombres válidos: ns1 ldap www mail ftp
Ejemplo: ./scripts/set-ips.sh ldap=192.168.1.21 www=192.168.1.22
EOF
  exit 1
}

valid_ip() {
  local ip=$1 octet
  local -a octets
  [[ ${ip} =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]] || return 1
  IFS=. read -r -a octets <<< "${ip}"
  for octet in "${octets[@]}"; do
    [[ ${octet} == 0 || ${octet} != 0* ]] || return 1
    (( 10#${octet} <= 255 )) || return 1
  done
  [[ ${ip} != 0.0.0.0 && ${ip} != 255.255.255.255 ]]
}

(( $# >= 1 )) || usage
if ! command -v named-checkzone >/dev/null; then
  echo "Error: falta named-checkzone (paquete bind9-utils). Ejecute este script en ns1." >&2
  exit 1
fi
if [[ ! -f ${ZONE_FILE} ]]; then
  echo "Error: no existe ${ZONE_FILE}." >&2
  exit 1
fi

declare -A NEW=()
for arg in "$@"; do
  [[ ${arg} == *=* ]] || usage
  name=${arg%%=*}
  ip=${arg#*=}
  if [[ -z ${name} || -z ${ROLE[${name}]:-} ]]; then
    echo "Error: nombre '${name}' no válido (use ns1, ldap, www, mail o ftp)." >&2
    exit 1
  fi
  if ! valid_ip "${ip}"; then
    echo "Error: '${ip}' no es una IPv4 válida." >&2
    exit 1
  fi
  NEW[${name}]=${ip}
done

WORK_FILE=$(mktemp)
trap 'rm -f "${WORK_FILE}"' EXIT
cp "${ZONE_FILE}" "${WORK_FILE}"

for name in ns1 ldap www mail ftp; do
  [[ -n ${NEW[${name}]:-} ]] || continue
  if ! grep -Eq "^${name}[[:space:]]+IN[[:space:]]+A[[:space:]]" "${WORK_FILE}"; then
    echo "Error: la zona no tiene registro A para ${name}." >&2
    exit 1
  fi
  old=$(awk -v n="${name}" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "${WORK_FILE}")
  line=$(printf '%-7s IN  A    %-15s ; %s' "${name}" "${NEW[${name}]}" "${ROLE[${name}]}")
  sed -i -E "s|^${name}[[:space:]]+IN[[:space:]]+A[[:space:]].*\$|${line}|" "${WORK_FILE}"
  printf '%-5s %s -> %s\n' "${name}" "${old}" "${NEW[${name}]}"
done

# Serial AAAAMMDDNN: si ya hay uno de hoy se incrementa NN; si no, empieza en 01.
current=$(awk '/;[[:space:]]*serial/ {print $1; exit}' "${WORK_FILE}")
if [[ ! ${current} =~ ^[0-9]{10}$ ]]; then
  echo "Error: no pude leer el serial de la zona." >&2
  exit 1
fi
base=$(( $(date +%Y%m%d) * 100 ))
if (( current > base )); then
  next=$(( current + 1 ))
else
  next=$(( base + 1 ))
fi
sed -i -E "s|^([[:space:]]*)${current}([[:space:]]+;[[:space:]]*serial)|\1${next}\2|" "${WORK_FILE}"
printf 'serial %s -> %s\n' "${current}" "${next}"

if ! named-checkzone "${DOMAIN}" "${WORK_FILE}" >/dev/null; then
  echo "Error: la zona resultante no es válida; no se guardó ningún cambio." >&2
  named-checkzone "${DOMAIN}" "${WORK_FILE}" >&2 || true
  exit 1
fi

# Se escribe sobre el mismo archivo para conservar su dueño y sus permisos.
cat "${WORK_FILE}" > "${ZONE_FILE}"
ZONE_FILE="${ZONE_FILE}" bash "${SCRIPT_DIR}/gen-table.sh"

if [[ ${DEPLOY} == 1 ]]; then
  if [[ ${EUID} -eq 0 ]]; then
    bash "${SCRIPT_DIR}/install.sh"
  else
    sudo bash "${SCRIPT_DIR}/install.sh"
  fi
fi

pending=$(awk '$2 == "IN" && $3 == "A" && $4 ~ /^192\.0\.2\./ {printf "%s ", $1}' "${ZONE_FILE}")
if [[ -n ${pending} ]]; then
  echo "Aviso: todavía falta la IP real de: ${pending}"
fi
