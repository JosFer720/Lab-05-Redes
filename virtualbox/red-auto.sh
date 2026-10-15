#!/usr/bin/env bash
# Mantiene el laboratorio alcanzable cuando cambia la red de la VM (otro Wi-Fi, otro hotspot, un DHCP que entrega otra IP).
# Si la IP del adaptador en puente ya no coincide con la de ns1 en la zona, con la ACL de recursión de BIND, con el FTP pasivo
# o con las reglas de UFW, ejecuta cambiar-ip.sh, que conserva las IPs que ya se cargaron para los compañeros (ldap, www,
# mail, ftp) si siguen siendo de la red actual, y mueve a la IP nueva de la VM los nombres que apuntaban a ella o a una
# red anterior (la VM tiene los cinco servicios de respaldo). Sin cambios no hace nada.
# Lo ejecuta cada minuto el temporizador lab5-red-auto (virtualbox/instalar-red-auto.sh). Uso manual:
#   sudo bash /opt/lab5/virtualbox/red-auto.sh                   aplica si hace falta
#   sudo bash /opt/lab5/virtualbox/red-auto.sh --solo-comprobar  solo dice qué haría
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
exec 9>/run/lab5-red-auto.lock
flock -n 9 || exit 0
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
IFACE=${LAB_IFACE:-enp0s8}
DRY=0
[[ ${1:-} == --solo-comprobar ]] && DRY=1
ZONE=/etc/bind/zones/db.aerolinea.redes.test
[[ -f $ZONE ]] || exit 0

CIDR=$(ip -4 -o addr show dev "$IFACE" scope global 2>/dev/null | awk 'NR==1 {print $4}')
[[ -n $CIDR ]] || exit 0                      # sin IPv4 (Wi-Fi caído o DHCP en curso): se reintenta en un minuto
IP=${CIDR%/*}
NET=$(python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$CIDR")

zone_ip() { awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "$ZONE"; }
# La red de una regla o de la ACL es válida si es la de la VM o una más ancha que la contiene (por ejemplo /16 puesta a mano).
cubre() { python3 -c 'import ipaddress,sys; sys.exit(0 if ipaddress.ip_network(sys.argv[1]).subnet_of(ipaddress.ip_network(sys.argv[2], strict=False)) else 1)' "$1" "$2" 2>/dev/null; }
OLD_NS1=$(zone_ip ns1)
ACL_NET=$(grep -m1 'acl "red-lab"' /etc/bind/named.conf.options 2>/dev/null | grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]+' | head -1 || true)
ACL_OK=0
[[ -n $ACL_NET ]] && cubre "$NET" "$ACL_NET" && ACL_OK=1
PASV_OK=1
if [[ -f /etc/vsftpd.conf ]]; then
  [[ $(grep -m1 '^pasv_address=' /etc/vsftpd.conf | cut -d= -f2) == "$IP" ]] || PASV_OK=0
fi
UFW_OK=1
if command -v ufw >/dev/null 2>&1; then
  UFW_NET=$(ufw status | awk -v i="$IFACE" '$1 == "53/udp" && $2 == "on" && $3 == i && $4 ~ /^ALLOW/ && !hecho {print $5; hecho = 1}')
  UFW_OK=0
  [[ -n $UFW_NET ]] && cubre "$NET" "$UFW_NET" && UFW_OK=1
fi

if [[ $OLD_NS1 == "$IP" && $ACL_OK == 1 && $PASV_OK == 1 && $UFW_OK == 1 ]]; then
  exit 0
fi

# cambiar-ip.sh conserva las IPs de los compañeros que siguen en la red actual y manda a la VM los demás nombres.
mensaje="Cambio de red detectado: ns1 ${OLD_NS1:-?} -> $IP (red $NET; ACL ${ACL_NET:-?} OK=$ACL_OK, FTP pasivo OK=$PASV_OK, UFW ${UFW_NET:-?} OK=$UFW_OK). Se ejecuta cambiar-ip.sh $CIDR"
echo "$mensaje"
(( DRY )) && { echo "(--solo-comprobar: no se cambió nada)"; exit 0; }
logger -t lab5-red-auto "$mensaje"      # solo se registra en el journal cuando de verdad se va a reconfigurar
LAB5_LOCK_HELD=1 bash "$ROOT/virtualbox/cambiar-ip.sh" "$CIDR"
