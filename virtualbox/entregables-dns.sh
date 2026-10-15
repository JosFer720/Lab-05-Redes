#!/usr/bin/env bash
# Reúne en una carpeta lo que se entrega de la parte DNS:
#   db.aerolinea.redes.test        archivo de zona (entregable c)
#   resolucion-dns.md              tabla de resolución de nombres (entregable b)
#   tabla-direccionamiento.md      IP de cada nombre y MAC de la VM (para el diagrama y la tabla de IPs)
#   evidencias/                    una salida por ID: DNS-01..06, MAIL-01, named-checkzone, INT-02/03/04
#   verificar-red-dns.txt          resultado del verificador (puerto 53 UDP y TCP, firewall, servicios de la zona)
#   named.conf.options/.local      configuración de BIND
#   info-vm.txt                    sistema, red, puertos y reglas de UFW
# Uso, dentro de la VM:   sudo bash /opt/lab5/virtualbox/entregables-dns.sh [carpeta]    (predeterminado /home/labadmin/entregable-dns)
# Desde Windows:          powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 entregables
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
IFACE=${LAB_IFACE:-enp0s8}
DOMAIN=aerolinea.redes.test
ZONE=/etc/bind/zones/db.$DOMAIN
OUT=${1:-/home/labadmin/entregable-dns}
CIDR=$(ip -4 -o addr show dev "$IFACE" scope global | awk 'NR==1 {print $4}')
[[ -n $CIDR ]] || { echo "El adaptador $IFACE no tiene IPv4: no se puede reunir la evidencia." >&2; exit 1; }
IP=${CIDR%/*}
NET=$(python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$CIDR")
MAC=$(cat "/sys/class/net/$IFACE/address")
zone_ip() { awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "$ZONE"; }

mkdir -p "$OUT/evidencias"
install -m 0644 "$ZONE" "$OUT/db.$DOMAIN"
ZONE_FILE="$ZONE" OUT_FILE="$OUT/resolucion-dns.md" bash "$ROOT/dns/scripts/gen-table.sh" >/dev/null
# Las consultas se hacen a la IP de la red (no a 127.0.0.1) para que "SERVER:" muestre la IP real que usan los demás.
DNS_SERVER=$IP OUT_DIR="$OUT/evidencias" bash "$ROOT/dns/scripts/collect-evidence.sh" >/dev/null
bash "$ROOT/virtualbox/verificar-red-dns.sh" > "$OUT/verificar-red-dns.txt" 2>&1 || true
install -m 0644 /etc/bind/named.conf.options "$OUT/named.conf.options"
install -m 0644 /etc/bind/named.conf.local "$OUT/named.conf.local"

{
  echo '# Tabla de direccionamiento (parte DNS)'
  echo
  echo "Generada el $(date -u '+%F %T UTC') en la VM ns1 (las horas de la VM están en UTC; Guatemala es UTC-6). Red: $NET."
  echo
  echo '| Nombre | IP | Servicio | Equipo |'
  echo '|---|---|---|---|'
  for par in ns1:BIND9 ldap:OpenLDAP www:Apache mail:'Postfix + Dovecot' ftp:vsftpd; do
    n=${par%%:*}; servicio=${par#*:}; addr=$(zone_ip "$n")
    if [[ $addr == "$IP" ]]; then equipo='VM de Ian (CC3067-Lab5-Ubuntu)'; else equipo='equipo del compañero (completar nombre)'; fi
    echo "| $n.$DOMAIN | $addr | $servicio | $equipo |"
  done
  echo
  echo "MAC del adaptador en puente de la VM ($IFACE): **$MAC** (en Wi-Fi, los paquetes salen al aire con la MAC de la tarjeta del equipo anfitrión)."
} > "$OUT/tabla-direccionamiento.md"

{
  echo "# Información de la VM ($(date -u '+%F %T UTC'))"
  echo '## Sistema'; hostnamectl 2>/dev/null | sed -n '1,8p'
  echo; echo '## Red'; ip -4 -br addr; ip route
  echo; echo '## Puertos de DNS (INT-03)'; ss -lntup | grep -E '^Netid|[:.]53[[:space:]]' | grep -v systemd-resolve || true
  echo; echo '## Firewall (UFW)'; ufw status || true
  echo; echo '## Servicios'; systemctl is-active named slapd apache2 postfix@- dovecot vsftpd
  echo; echo '## Reenviadores de BIND'; grep -E 'forwarders|dnssec|acl "red-lab"' /etc/bind/named.conf.options
} > "$OUT/info-vm.txt" 2>&1

chown -R labadmin:labadmin "$OUT" 2>/dev/null || true
echo "Entregables de DNS reunidos en $OUT:"
(cd "$OUT" && find . -type f | sort | sed 's|^\./|  |')
