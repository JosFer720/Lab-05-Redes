#!/usr/bin/env bash
# Verificación local de ns1: servicio, puertos, archivos y respuestas de BIND.
# Ejecutar en la VM del DNS: sudo ./scripts/verify-local.sh
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
SERVER=${DNS_SERVER:-${SERVER:-127.0.0.1}}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZONE_SOURCE=${SCRIPT_DIR}/../zones/db.${DOMAIN}
ZONE_TARGET=/etc/bind/zones/db.${DOMAIN}
failed=0

check() {
  local description=$1
  shift
  if "$@" >/dev/null 2>&1; then
    printf '[PASS] %s\n' "${description}"
  else
    printf '[FAIL] %s\n' "${description}" >&2
    failed=1
  fi
}

zone_ip() {
  awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "${ZONE_SOURCE}"
}
zone_serial() {
  awk '/;[[:space:]]*serial/ {print $1; exit}' "$1"
}
ask() {
  dig +norecurse +time=3 +tries=1 "@${SERVER}" "$@"
}

listens_udp() { ss -lunH | grep -Eq '[:.]53[[:space:]]'; }
listens_tcp() { ss -ltnH | grep -Eq '[:.]53[[:space:]]'; }
serial_valid() { [[ $(zone_serial "${ZONE_TARGET}") =~ ^[0-9]{10}$ ]]; }
answers_ip() { [[ -n $2 && $(ask +short "$1.${DOMAIN}" A) == "$2" ]]; }
answers_tcp() { [[ $(ask +tcp +short "ns1.${DOMAIN}" A) == "$(zone_ip ns1)" ]]; }
authoritative_soa() { ask "${DOMAIN}" SOA | grep -Eq 'flags:[^;]* aa[ ;]'; }
ns_record() { [[ $(ask +short "${DOMAIN}" NS) == "ns1.${DOMAIN}." ]]; }
mx_record() { [[ $(ask +short "${DOMAIN}" MX) == "10 mail.${DOMAIN}." ]]; }
nxdomain() { ask "noexiste.${DOMAIN}" A | grep -q 'status: NXDOMAIN'; }
loaded_serial_matches() {
  [[ $(rndc zonestatus "${DOMAIN}" | awk '/^serial:/ {print $2}') == "$(zone_serial "${ZONE_TARGET}")" ]]
}

check 'servicio activo' systemctl is-active --quiet named
check 'servicio habilitado al arranque' systemctl is-enabled --quiet named
check 'puerto 53/udp escuchando' listens_udp
check 'puerto 53/tcp escuchando' listens_tcp
check 'named-checkconf sin errores' named-checkconf /etc/bind/named.conf
check 'named-checkzone sin errores' named-checkzone "${DOMAIN}" "${ZONE_TARGET}"
check 'zona desplegada igual a la del repositorio' cmp -s "${ZONE_SOURCE}" "${ZONE_TARGET}"
check 'serial con formato AAAAMMDDNN' serial_valid
if [[ ${EUID} -eq 0 ]]; then
  check 'BIND tiene cargado el serial del archivo' loaded_serial_matches
else
  printf '[WARN] ejecute con sudo para comprobar el serial cargado en memoria\n'
fi
check 'respuesta autoritativa para el SOA (flag aa)' authoritative_soa
for host in ns1 ldap www mail ftp; do
  expected=$(zone_ip "${host}")
  check "A ${host}.${DOMAIN} = ${expected}" answers_ip "${host}" "${expected}"
done
check 'NS = ns1' ns_record
check 'MX = 10 mail' mx_record
check 'nombre inexistente da NXDOMAIN' nxdomain
check 'consultas DNS por TCP' answers_tcp

pending=$(awk '$2 == "IN" && $3 == "A" && $4 ~ /^192\.0\.2\./ {printf "%s ", $1}' "${ZONE_SOURCE}")
if [[ -n ${pending} ]]; then
  printf '[WARN] IP pendiente (192.0.2.x) en la zona: %s\n' "${pending}"
else
  printf '[PASS] la zona no tiene IPs pendientes\n'
fi
if [[ -z $(dig +short +time=5 +tries=1 "@${SERVER}" ubuntu.com A 2>/dev/null) ]]; then
  printf '[WARN] no resuelve nombres externos (¿sin internet o forwarders bloqueados?)\n'
else
  printf '[PASS] resuelve nombres externos mediante forwarders\n'
fi

exit "${failed}"
