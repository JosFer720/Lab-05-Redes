#!/usr/bin/env bash
# Actualiza el laboratorio cuando cambia la IP (o la red) del adaptador en puente:
# zona DNS y ACL de recursión de BIND, dirección pasiva de vsftpd y reglas de UFW.
# Uso, dentro de la VM:
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh                  detecta IP y red de enp0s8
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh 192.168.1.50/24  usa esa IP y esa red
# Si los demás servicios corren en las computadoras de los compañeros (cada uno con el suyo), se indican sus IPs;
# ns1 siempre es esta VM y lo que no se indique también apunta a ella:
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh ldap=192.168.1.21 www=192.168.1.22 mail=192.168.1.23 ftp=192.168.1.24
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh 192.168.1.50/24 ldap=192.168.1.21
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Interfaz y puertos con que se instaló (los guarda instalar-servicios.sh); sin ese archivo, los de la VM VirtualBox.
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
LAB_IFACE=${LAB_IFACE:-enp0s8}
LAB_PORTS=${LAB_PORTS:-53 80 389 25 587 143 21}
CIDR=''
declare -A OTRAS_IPS=()
for arg in "$@"; do
  if [[ $arg =~ ^(ldap|www|mail|ftp)=([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    OTRAS_IPS[${arg%%=*}]=${arg#*=}
  elif [[ -z $CIDR && $arg =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    CIDR=$arg
  else
    echo "Argumento no válido: $arg (use IP/prefijo, o nombre=IP con ldap, www, mail o ftp)" >&2
    exit 1
  fi
done
CIDR=${CIDR:-$(ip -4 -o addr show dev "$LAB_IFACE" scope global | awk 'NR==1 {print $4}')}
if [[ ! ${CIDR:-} =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
  echo "No hay IPv4 en $LAB_IFACE: ¿la VM tiene el adaptador en puente conectado y con DHCP?" >&2
  exit 1
fi
LAB_IP=${CIDR%/*}
LAB_NETWORK=$(python3 -c 'import ipaddress,sys; print(ipaddress.ip_interface(sys.argv[1]).network)' "$CIDR")
echo "IP del laboratorio: $LAB_IP   red: $LAB_NETWORK   interfaz: $LAB_IFACE"

# 1) Zona DNS (ns1 es esta VM; los demás nombres también, salvo los que se indicaron) y red permitida para recursión.
export LOCAL_NETWORK=$LAB_NETWORK
bash "$ROOT/dns/scripts/set-ips.sh" ns1="$LAB_IP" ldap="${OTRAS_IPS[ldap]:-$LAB_IP}" www="${OTRAS_IPS[www]:-$LAB_IP}" \
  mail="${OTRAS_IPS[mail]:-$LAB_IP}" ftp="${OTRAS_IPS[ftp]:-$LAB_IP}"

# 2) FTP en modo pasivo debe anunciar la IP actual.
if grep -q '^pasv_address=' /etc/vsftpd.conf; then
  sed -i "s|^pasv_address=.*|pasv_address=$LAB_IP|" /etc/vsftpd.conf
else
  echo "pasv_address=$LAB_IP" >> /etc/vsftpd.conf
fi
systemctl restart vsftpd

# 3) UFW: se reconstruye el conjunto completo de reglas con la red nueva.
ufw --force reset >/dev/null
ufw default deny incoming
ufw default allow outgoing
ufw allow in on enp0s3 to any port 22 proto tcp
for port in $LAB_PORTS; do
  ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port "$port" proto tcp
done
ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port 53 proto udp
ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port 40000:40100 proto tcp
ufw --force enable

systemctl is-active named slapd apache2 postfix dovecot vsftpd || true   # alguno puede estar detenido a propósito
for nombre in ns1 ldap www mail ftp; do
  echo "  $nombre.aerolinea.redes.test -> $(dig +short @127.0.0.1 "$nombre.aerolinea.redes.test")"
done
echo "Listo. Los demás equipos deben usar $LAB_IP como DNS."
