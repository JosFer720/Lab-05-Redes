#!/usr/bin/env bash
# Actualiza el laboratorio cuando cambia la IP (o la red) del adaptador en puente:
# zona DNS y ACL de recursión de BIND, salida a Internet de BIND, dirección pasiva de vsftpd y reglas de UFW.
# Uso, dentro de la VM:
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh                  detecta la IP y la red de enp0s8
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh 192.168.1.50/24  usa esa IP y esa red
# ns1 siempre es esta VM. Cuando los demás servicios corren en las computadoras de los compañeros (cada uno con el suyo)
# se indican sus IPs; lo que no se indique CONSERVA su valor actual (si apuntaba a esta VM, sigue a la IP nueva de la VM;
# si su IP no pertenece a la red actual, por ejemplo tras cambiar de Wi-Fi, vuelve a esta VM, que tiene los cinco servicios):
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh ldap=192.168.1.21 www=192.168.1.22 mail=192.168.1.23 ftp=192.168.1.24
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh www=192.168.1.30            (solo cambia www; los demás quedan igual)
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh ldap=vm                     (ese nombre vuelve a esta VM, que tiene los cinco servicios)
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh --todo-en-la-vm             (los cinco nombres vuelven a esta VM)
#   sudo bash /opt/lab5/virtualbox/cambiar-ip.sh --simular [lo demás]        muestra la zona que quedaría, sin cambiar nada
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
# Una sola reconfiguración a la vez (el temporizador lab5-red-auto usa el mismo candado y avisa con LAB5_LOCK_HELD).
if [[ -z ${LAB5_LOCK_HELD:-} ]]; then
  exec 9>/run/lab5-red-auto.lock
  flock 9
fi
# Interfaz y puertos con que se instaló (los guarda instalar-servicios.sh); sin ese archivo, los de la VM VirtualBox.
[[ -f /root/lab5-private/red.env ]] && source /root/lab5-private/red.env
LAB_IFACE=${LAB_IFACE:-enp0s8}
LAB_PORTS=${LAB_PORTS:-53 80 389 25 587 143 21}
CIDR=''
RESET=0
SIMULAR=0
declare -A OTRAS_IPS=()
for arg in "$@"; do
  if [[ $arg =~ ^(ldap|www|mail|ftp)=(vm|([0-9]{1,3}\.){3}[0-9]{1,3})$ ]]; then
    OTRAS_IPS[${arg%%=*}]=${arg#*=}
  elif [[ $arg == --todo-en-la-vm ]]; then
    RESET=1
  elif [[ $arg == --simular ]]; then
    SIMULAR=1
  elif [[ -z $CIDR && $arg =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}/[0-9]{1,2}$ ]]; then
    CIDR=$arg
  else
    echo "Argumento no válido: $arg (use IP/prefijo, nombre=IP o nombre=vm con ldap, www, mail o ftp, --todo-en-la-vm o --simular)" >&2
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

# 1) Zona DNS y red permitida para recursión. Por nombre: la IP indicada; si no se indicó, la que ya tenía, salvo que
#    apuntara a esta VM (la IP vieja de ns1), en cuyo caso sigue a la IP nueva de la VM.
ZONE_REPO=$ROOT/dns/zones/db.aerolinea.redes.test
zone_ip() { awk -v n="$1" '$1 == n && $2 == "IN" && $3 == "A" {print $4; exit}' "$ZONE_REPO"; }
en_la_red() { python3 -c 'import ipaddress,sys; sys.exit(0 if ipaddress.ip_address(sys.argv[1]) in ipaddress.ip_network(sys.argv[2], strict=False) else 1)' "$1" "$LAB_NETWORK"; }
OLD_NS1=$(zone_ip ns1)
declare -A NUEVA=()
for nombre in ldap www mail ftp; do
  if [[ -n ${OTRAS_IPS[$nombre]:-} ]]; then
    NUEVA[$nombre]=${OTRAS_IPS[$nombre]}
    if [[ ${NUEVA[$nombre]} == vm ]]; then NUEVA[$nombre]=$LAB_IP; fi
  elif (( RESET )); then
    NUEVA[$nombre]=$LAB_IP
  else
    actual=$(zone_ip "$nombre")
    if [[ -z $actual || $actual == "$OLD_NS1" || $actual == "$LAB_IP" ]]; then
      NUEVA[$nombre]=$LAB_IP
    elif en_la_red "$actual"; then
      NUEVA[$nombre]=$actual
    else
      # La IP de un compañero de OTRA red no sirve en esta: el nombre vuelve a esta VM (que tiene los cinco servicios de
      # respaldo) para que el laboratorio funcione desde el primer minuto. Se carga la IP nueva con: ips $nombre=<IP>.
      echo "  Aviso: $nombre apuntaba a $actual, que no es de la red $LAB_NETWORK: vuelve a esta VM. Cargue la IP nueva con: ips $nombre=<IP>" >&2
      NUEVA[$nombre]=$LAB_IP
    fi
  fi
done
if (( SIMULAR )); then
  echo "--- SIMULACRO: la zona quedaría así (no se cambia nada) ---"
  printf '  %-5s %-16s (ahora: %s)\n' ns1 "$LAB_IP" "$OLD_NS1"
  for nombre in ldap www mail ftp; do printf '  %-5s %-16s (ahora: %s)\n' "$nombre" "${NUEVA[$nombre]}" "$(zone_ip "$nombre")"; done
  echo "  ACL de recursión y reglas de UFW: $LAB_NETWORK; FTP pasivo: $LAB_IP"
  exit 0
fi
export LOCAL_NETWORK=$LAB_NETWORK
bash "$ROOT/dns/scripts/set-ips.sh" ns1="$LAB_IP" ldap="${NUEVA[ldap]}" www="${NUEVA[www]}" mail="${NUEVA[mail]}" ftp="${NUEVA[ftp]}"

# 1b) set-ips.sh reinstala la configuración del repo: se vuelve a ajustar la salida a Internet para la red actual
#     (DNS del DHCP primero y sin DNSSEC), si no BIND falla en hotspots que bloquean 1.1.1.1.
LAB_IFACE=$LAB_IFACE bash "$ROOT/virtualbox/ajustar-dns-salida.sh" || echo "Aviso: no se pudo ajustar la salida a Internet de BIND." >&2

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
