#!/usr/bin/env bash
# Guarda en docs/evidencias/dns/ la salida completa de cada prueba DNS,
# un archivo por ID de la matriz (DNS-01 ... DNS-05, MAIL-01, INT-02/03/04).
#
#   En ns1:          ./scripts/collect-evidence.sh
#   Desde un cliente: DNS_SERVER=<IP de ns1> ./scripts/collect-evidence.sh
#
# Con DNS_SERVER distinto de 127.0.0.1 solo se hacen las consultas DNS y la
# validación de la zona; el estado del servicio, los puertos y los logs
# (INT-02/03/04) se recolectan únicamente en ns1.
set -Eeuo pipefail

DOMAIN=${DOMAIN:-aerolinea.redes.test}
DNS_SERVER=${DNS_SERVER:-127.0.0.1}
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
ZONE_SOURCE=${SCRIPT_DIR}/../zones/db.${DOMAIN}
OUT_DIR=${OUT_DIR:-${SCRIPT_DIR}/../../docs/evidencias/dns}
STAMP=$(date '+%Y-%m-%d %H:%M:%S %Z')

SUDO=
if [[ ${EUID} -ne 0 ]]; then
  SUDO=sudo
fi
LOCAL=${LOCAL:-auto}
if [[ ${LOCAL} == auto ]]; then
  LOCAL=0
  if [[ ${DNS_SERVER} == 127.0.0.1 || ${DNS_SERVER} == localhost ]] || \
      ip -4 -o address show | awk '{sub(/\/.*/, "", $4); print $4}' | grep -Fxq "${DNS_SERVER}"; then
    LOCAL=1
  fi
fi

mkdir -p "${OUT_DIR}"
CURRENT=
FILES=()

begin() {
  CURRENT=${OUT_DIR}/$1.txt
  FILES+=("${CURRENT}")
  {
    printf '# %s\n' "$2"
    printf '# Fecha: %s | Equipo: %s | Servidor DNS consultado: %s\n' \
      "${STAMP}" "$(hostname)" "${DNS_SERVER}"
  } > "${CURRENT}"
}

# run: registra el comando y su salida completa.
run() {
  { printf '\n$ %s\n' "$*"; "$@" 2>&1 || true; } >> "${CURRENT}"
}

# run_shell: igual, pero para comandos con tuberías (se muestra tal cual).
run_shell() {
  { printf '\n$ %s\n' "$1"; bash -c "$1" 2>&1 || true; } >> "${CURRENT}"
}

begin DNS-01 'DNS-01 Resolución del servidor DNS: ns1'
run dig "@${DNS_SERVER}" "ns1.${DOMAIN}" A
run nslookup "ns1.${DOMAIN}" "${DNS_SERVER}"

begin DNS-02 'DNS-02 Resolución de los servicios: ldap, www, mail y ftp'
for host in ldap www mail ftp; do
  run dig "@${DNS_SERVER}" "${host}.${DOMAIN}" A
done
run nslookup "ldap.${DOMAIN}" "${DNS_SERVER}"

begin DNS-03 'DNS-03 Consulta de servidor autoritativo: SOA y NS (buscar "aa" en flags)'
run dig "@${DNS_SERVER}" "${DOMAIN}" SOA
run dig "@${DNS_SERVER}" "${DOMAIN}" NS

begin DNS-04 'DNS-04 Consulta del servidor de correo: MX'
run dig "@${DNS_SERVER}" "${DOMAIN}" MX

begin DNS-05 'DNS-05 Consulta de nombre inexistente (debe dar NXDOMAIN)'
run dig "@${DNS_SERVER}" "noexiste.${DOMAIN}" A

begin DNS-06 'DNS-06 Resolución del servidor DNS por TCP'
run dig +tcp "@${DNS_SERVER}" "ns1.${DOMAIN}" A

begin MAIL-01 'MAIL-01 Resolución del servidor de correo: A de mail y registro MX'
run dig "@${DNS_SERVER}" "mail.${DOMAIN}" A
run dig "@${DNS_SERVER}" "${DOMAIN}" MX

begin named-checkzone 'Validación de la configuración y de la zona'
if command -v named-checkconf >/dev/null; then
  run_shell 'named-checkconf /etc/bind/named.conf && echo "named-checkconf: sin errores"'
fi
if command -v named-checkzone >/dev/null; then
  run named-checkzone "${DOMAIN}" "${ZONE_SOURCE}"
else
  printf '\n(named-checkzone no está instalado en este equipo)\n' >> "${CURRENT}"
fi

if (( LOCAL )); then
  begin INT-02-dns 'INT-02 Estado del servicio named (repetir después de reiniciar)'
  run systemctl is-active named
  run systemctl is-enabled named
  run_shell 'systemctl --no-pager --full status named | head -n 14'

  begin INT-03-dns 'INT-03 Puertos en escucha de ns1 (53 UDP y TCP)'
  run_shell "${SUDO:+${SUDO} }ss -lntup | grep -E '^Netid|[:.]53[[:space:]]'"

  begin INT-04-dns 'INT-04 Logs de named: arranque de la zona y consultas recibidas'
  run_shell "${SUDO:+${SUDO} }journalctl -u named --no-pager -n 60"
fi

echo 'Evidencias guardadas:'
printf '  %s\n' "${FILES[@]}"
