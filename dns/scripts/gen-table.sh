#!/usr/bin/env bash
# Genera docs/tablas/resolucion-dns.md (entregable b) a partir de la zona.
# No editar la tabla a mano: se vuelve a generar con este script.
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZONE_FILE=${ZONE_FILE:-${SCRIPT_DIR}/../zones/db.${DOMAIN}}
OUT_FILE=${OUT_FILE:-${SCRIPT_DIR}/../../docs/tablas/resolucion-dns.md}

if [[ ! -f ${ZONE_FILE} ]]; then
  echo "Error: no existe ${ZONE_FILE}." >&2
  exit 1
fi
mkdir -p "$(dirname "${OUT_FILE}")"

ttl=$(awk '$1 == "$TTL" {print $2; exit}' "${ZONE_FILE}")
serial=$(awk '/;[[:space:]]*serial/ {print $1; exit}' "${ZONE_FILE}")
soa_ns=$(awk '$3 == "SOA" {print $4; exit}' "${ZONE_FILE}")
soa_mail=$(awk '$3 == "SOA" {print $5; exit}' "${ZONE_FILE}")
ns_host=$(awk '$1 == "@" && $3 == "NS" {print $4; exit}' "${ZONE_FILE}")
mx_pref=$(awk '$1 == "@" && $3 == "MX" {print $4; exit}' "${ZONE_FILE}")
mx_host=$(awk '$1 == "@" && $3 == "MX" {print $5; exit}' "${ZONE_FILE}")

{
  printf '# Tabla de resolución de nombres DNS\n\n'
  printf 'Zona autoritativa %s, servida por BIND9 en ns1. Serial %s, TTL %s s.\n' \
    "${DOMAIN}" "${serial}" "${ttl}"
  printf 'Generada por dns/scripts/gen-table.sh a partir de dns/zones/db.%s.\n\n' "${DOMAIN}"
  printf '| Nombre | Tipo | Valor | TTL (s) | Servicio |\n'
  printf '|---|---|---|---|---|\n'
  printf '| %s. | SOA | %s %s (serial %s) | %s | Autoridad de la zona |\n' \
    "${DOMAIN}" "${soa_ns}" "${soa_mail}" "${serial}" "${ttl}"
  printf '| %s. | NS | %s | %s | Servidor de nombres |\n' "${DOMAIN}" "${ns_host}" "${ttl}"
  printf '| %s. | MX | %s %s | %s | Correo (prioridad %s) |\n' \
    "${DOMAIN}" "${mx_pref}" "${mx_host}" "${ttl}" "${mx_pref}"
  awk -v d="${DOMAIN}" -v ttl="${ttl}" '
    $2 == "IN" && $3 == "A" {
      role = $0
      sub(/^[^;]*;[[:space:]]*/, "", role)
      pend = ($4 ~ /^192\.0\.2\./) ? " (PENDIENTE)" : ""
      printf "| %s.%s. | A | %s%s | %s | %s |\n", $1, d, $4, pend, ttl, role
    }' "${ZONE_FILE}"
} > "${OUT_FILE}"

echo "Tabla generada: ${OUT_FILE}"
