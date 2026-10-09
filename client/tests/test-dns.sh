#!/usr/bin/env bash
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZONE_FILE=${ZONE_FILE:-${SCRIPT_DIR}/../../dns/zones/db.${DOMAIN}}
# Vacío: se usa el DNS configurado en el cliente (debe ser ns1). Con valor: se consulta ese servidor.
DNS_SERVER=${DNS_SERVER:-}
DNS_PORT=${DNS_PORT:-53}

if [[ ! ${DNS_PORT} =~ ^[0-9]{1,5}$ ]]; then
  echo "Error: DNS_PORT debe ser un puerto entre 1 y 65535." >&2
  exit 1
fi
DNS_PORT=$(( 10#${DNS_PORT} ))
if (( DNS_PORT < 1 || DNS_PORT > 65535 )); then
  echo "Error: DNS_PORT debe ser un puerto entre 1 y 65535." >&2
  exit 1
fi

if [[ ! -f ${ZONE_FILE} ]]; then
  echo "Error: no encuentro la zona ${ZONE_FILE}; defina ZONE_FILE." >&2
  exit 1
fi

passed=0
failed=0
run_pass() {
  local id=$1 description=$2
  shift 2
  if "$@"; then
    printf '[PASS] %s %s\n' "${id}" "${description}"
    ((passed+=1))
  else
    printf '[FAIL] %s %s\n' "${id}" "${description}" >&2
    ((failed+=1))
  fi
}

zone_ip() {
  awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "${ZONE_FILE}"
}

NS1_IP=$(zone_ip ns1)
AUTH_SERVER=${DNS_SERVER:-${NS1_IP}}
CLIENT_DIG=(dig -p "${DNS_PORT}" +time=3 +tries=1)
if [[ -n ${DNS_SERVER} ]]; then
  CLIENT_DIG+=("@${DNS_SERVER}")
fi

resolves_to() {
  [[ -n $2 && $("${CLIENT_DIG[@]}" +short "$1.${DOMAIN}" A) == "$2" ]]
}
authoritative_soa() {
  dig -p "${DNS_PORT}" +norecurse +time=3 +tries=1 "@${AUTH_SERVER}" "${DOMAIN}" SOA | grep -Eq 'flags:[^;]* aa[ ;]'
}
ns_record() {
  [[ $(dig -p "${DNS_PORT}" +short +time=3 +tries=1 "@${AUTH_SERVER}" "${DOMAIN}" NS) == "ns1.${DOMAIN}." ]]
}
mx_record() {
  [[ $(dig -p "${DNS_PORT}" +short +time=3 +tries=1 "@${AUTH_SERVER}" "${DOMAIN}" MX) == "10 mail.${DOMAIN}." ]]
}
nxdomain() {
  dig -p "${DNS_PORT}" +time=3 +tries=1 "@${AUTH_SERVER}" "noexiste.${DOMAIN}" A | grep -q 'status: NXDOMAIN'
}
tcp_response() {
  [[ -n ${NS1_IP} && $(dig -p "${DNS_PORT}" +tcp +short +time=3 +tries=1 "@${AUTH_SERVER}" "ns1.${DOMAIN}" A) == "${NS1_IP}" ]]
}
no_pending_ips() {
  ! awk '$2 == "IN" && $3 == "A" && $4 ~ /^192\.0\.2\./ {found = 1} END {exit !found}' "${ZONE_FILE}"
}

run_pass DNS-01 "ns1.${DOMAIN} devuelve ${NS1_IP}" resolves_to ns1 "${NS1_IP}"
for entry in a:ldap b:www c:mail d:ftp; do
  suffix=${entry%%:*}
  host=${entry#*:}
  run_pass "DNS-02${suffix}" "${host}.${DOMAIN} devuelve $(zone_ip "${host}")" \
    resolves_to "${host}" "$(zone_ip "${host}")"
done
run_pass DNS-02e 'la zona no tiene IPs pendientes (192.0.2.x)' no_pending_ips
run_pass DNS-03a 'SOA con respuesta autoritativa (flag aa)' authoritative_soa
run_pass DNS-03b "NS de la zona es ns1.${DOMAIN}" ns_record
run_pass DNS-04 "MX de la zona es mail.${DOMAIN} (prioridad 10)" mx_record
run_pass DNS-05 'nombre inexistente responde NXDOMAIN' nxdomain
run_pass DNS-06 'resolución DNS también disponible por TCP' tcp_response

printf '\nResultado: %d PASS, %d FAIL\n' "${passed}" "${failed}"
(( failed == 0 ))
