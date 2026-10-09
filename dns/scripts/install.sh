#!/usr/bin/env bash
# Instala BIND9 y despliega la configuración y la zona del repositorio.
# Se puede repetir las veces que haga falta (después de cambiar la zona, por ejemplo).
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

DOMAIN=${DOMAIN:-aerolinea.redes.test}
NAMED_THREADS=${NAMED_THREADS:-2}

if [[ ! ${NAMED_THREADS} =~ ^[0-9]+$ ]] || (( NAMED_THREADS < 1 )); then
  echo "Error: NAMED_THREADS debe ser un entero positivo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
CONFIG_DIR=${SCRIPT_DIR}/../config
ZONE_SOURCE=${SCRIPT_DIR}/../zones/db.${DOMAIN}
ZONE_DIR=/etc/bind/zones
ZONE_TARGET=${ZONE_DIR}/db.${DOMAIN}
export DEBIAN_FRONTEND=noninteractive

for file in "${CONFIG_DIR}/named.conf.options" "${CONFIG_DIR}/named.conf.local" "${ZONE_SOURCE}"; do
  if [[ ! -f ${file} ]]; then
    echo "Error: falta ${file}." >&2
    exit 1
  fi
done

if ! dpkg -s bind9 bind9-utils bind9-dnsutils >/dev/null 2>&1; then
  apt-get update
  apt-get install -y bind9 bind9-utils bind9-dnsutils
fi

# Acepta también las IPs por ambiente, como el instalador del repositorio de pruebas.
IP_UPDATES=()
for entry in ns1:DNS_IP ldap:LDAP_IP www:WEB_IP mail:MAIL_IP ftp:FTP_IP; do
  host=${entry%%:*}
  variable=${entry#*:}
  if [[ -n ${!variable:-} ]]; then
    IP_UPDATES+=("${host}=${!variable}")
  fi
done
if (( ${#IP_UPDATES[@]} )); then
  DEPLOY=0 bash "${SCRIPT_DIR}/set-ips.sh" "${IP_UPDATES[@]}"
fi

# Validar lo que dice el repositorio antes de tocar /etc/bind.
TMP_DIR=$(mktemp -d)
trap 'rm -rf "${TMP_DIR}"' EXIT
cp "${CONFIG_DIR}/named.conf.options" "${TMP_DIR}/named.conf.options"
if [[ -n ${LOCAL_NETWORK:-} ]]; then
  if [[ ! ${LOCAL_NETWORK} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/([0-9]|[12][0-9]|3[0-2])$ ]]; then
    echo "Error: LOCAL_NETWORK debe ser una red IPv4 con prefijo CIDR." >&2
    exit 1
  fi
  sed -i "/^acl \"red-lab\" {/,/^};/c\\acl \"red-lab\" { localhost; ${LOCAL_NETWORK}; };" \
    "${TMP_DIR}/named.conf.options"
fi
printf 'include "%s";\ninclude "%s";\n' \
  "${TMP_DIR}/named.conf.options" "${CONFIG_DIR}/named.conf.local" > "${TMP_DIR}/named.conf"
named-checkconf "${TMP_DIR}/named.conf"
named-checkzone "${DOMAIN}" "${ZONE_SOURCE}"

deploy_config() {
  local source=$1 target=$2
  if [[ -f ${target} ]] && ! cmp -s "${source}" "${target}"; then
    local backup=${target}.bak.$(date +%Y%m%d%H%M%S)
    cp -a "${target}" "${backup}"
    echo "Respaldo creado: ${backup}"
  fi
  install -o root -g bind -m 0644 "${source}" "${target}"
}

deploy_config "${TMP_DIR}/named.conf.options" /etc/bind/named.conf.options
deploy_config "${CONFIG_DIR}/named.conf.local" /etc/bind/named.conf.local
install -d -o root -g bind -m 0755 "${ZONE_DIR}"
deploy_config "${ZONE_SOURCE}" "${ZONE_TARGET}"

# Solo IPv4 y pocos hilos: BIND abre un socket por hilo y por IP, y con
# muchos núcleos la salida de "ss -lntup" queda ilegible.
OPTIONS_LINE="OPTIONS=\"-u bind -4 -n ${NAMED_THREADS}\""
if [[ -f /etc/default/named ]]; then
  if ! grep -Fxq "${OPTIONS_LINE}" /etc/default/named; then
    cp -a /etc/default/named "/etc/default/named.bak.$(date +%Y%m%d%H%M%S)"
    if grep -q '^OPTIONS=' /etc/default/named; then
      sed -i -E "s|^OPTIONS=.*|${OPTIONS_LINE}|" /etc/default/named
    else
      printf '%s\n' "${OPTIONS_LINE}" >> /etc/default/named
    fi
  fi
else
  printf 'RESOLVCONF=no\n%s\n' "${OPTIONS_LINE}" > /etc/default/named
fi

named-checkconf /etc/bind/named.conf
named-checkzone "${DOMAIN}" "${ZONE_TARGET}"

systemctl enable named
systemctl restart named
systemctl --no-pager --full status named
echo "DNS instalado. Netplan, el DNS del sistema y UFW no fueron modificados."
