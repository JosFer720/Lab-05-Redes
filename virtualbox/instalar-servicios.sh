#!/usr/bin/env bash
# Requiere archivos privados fuera del repositorio; no incluye credenciales.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "${PRIVATE_ENV:-/root/lab5-private/deploy.env}"
export DOMAIN=aerolinea.redes.test BASE_DN=dc=aerolinea,dc=redes,dc=test
# Red del laboratorio. Los valores originales son host-only; en modo puente llegan por deploy.env
# (LAB_IP, LAB_NETWORK, LAB_IFACE, LAB_RESOLVER, LAB_PORTS) desde virtualbox/desplegar.py.
LAB_IP=${LAB_IP:-192.168.56.10}
LAB_NETWORK=${LAB_NETWORK:-192.168.56.0/24}
LAB_IFACE=${LAB_IFACE:-enp0s8}
LAB_RESOLVER=${LAB_RESOLVER:-$LAB_IP}
LAB_PORTS=${LAB_PORTS:-22 53 80 389 25 587 143 21}
export DNS_IP=$LAB_IP
export LDAP_IP=$DNS_IP WEB_IP=$DNS_IP MAIL_IP=$DNS_IP FTP_IP=$DNS_IP
export ORG_NAME=AeroQuetzal
export LOCAL_NETWORK=$LAB_NETWORK LDAP_HOST=ldap.aerolinea.redes.test LDAP_PORT=389 PASV_ADDRESS=$DNS_IP
export DEBIAN_FRONTEND=noninteractive
# Parche de temporizador solo para VirtualBox (en otros hipervisores o en ARM64 no hace falta).
if [[ $(systemd-detect-virt 2>/dev/null || true) == oracle ]]; then
  printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet noapic clocksource=acpi_pm"' > /etc/default/grub.d/99-lab5-timer.cfg
  update-grub
fi
# Evitar regenerar la base de sugerencias de comandos en cada apt update.
# Se conserva el archivo original para restaurarlo; no afecta paquetes/servicios.
install -d /var/backups/lab5
if [[ -f /etc/apt/apt.conf.d/50command-not-found ]]; then
  mv /etc/apt/apt.conf.d/50command-not-found /var/backups/lab5/50command-not-found
fi
apt-get update
apt-get install -y curl ca-certificates xz-utils python3 ufw
bash "$ROOT/dns/scripts/install.sh"
# En modo puente: reenviadores de BIND = DNS que entrega el DHCP de la red (si no hay, no cambia nada).
LAB_IFACE=$LAB_IFACE bash "$ROOT/virtualbox/ajustar-dns-salida.sh" || true
install -d /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNS=%s\nDomains=~aerolinea.redes.test\n' "$LAB_RESOLVER" > /etc/systemd/resolved.conf.d/lab5.conf
systemctl restart systemd-resolved
bash "$ROOT/ldap/scripts/install.sh"
ldapmodify -Q -Y EXTERNAL -H ldapi:/// <<'LDIF'
dn: cn=config
changetype: modify
replace: olcLogLevel
olcLogLevel: stats
LDIF
# Node LTS nativo, con verificación SHA256 de distribución oficial.
if ! command -v node >/dev/null || [[ $(node -p 'process.versions.node.split(".")[0]') -lt 24 ]]; then
  tmp=$(mktemp -d)
  case "$(dpkg --print-architecture)" in
    amd64) node_arch=x64 ;;
    arm64) node_arch=arm64 ;;
    *) echo "Arquitectura no soportada para Node: $(dpkg --print-architecture)" >&2; exit 1 ;;
  esac
  curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o "$tmp/SHASUMS256.txt"
  name=$(awk -v re="node-v24.*-linux-${node_arch}.tar.xz$" '$2 ~ re {print $2}' "$tmp/SHASUMS256.txt")
  [[ $name == node-v24.*-linux-${node_arch}.tar.xz && $name != *$'\n'* ]]
  curl -fsSL "https://nodejs.org/dist/latest-v24.x/$name" -o "$tmp/$name"
  (cd "$tmp"; grep " $name$" SHASUMS256.txt | sha256sum -c -)
  tar --no-same-owner -xJf "$tmp/$name" -C /usr/local --strip-components=1
  rm -rf "$tmp"
fi
(cd "$ROOT/web/site"; npm ci; npm run build)
bash "$ROOT/web/scripts/install.sh"
bash "$ROOT/mail/scripts/install.sh"
postconf -e 'mynetworks = 127.0.0.0/8 [::1]/128'
systemctl restart postfix
bash "$ROOT/ftp/scripts/install.sh"
# La VM nueva solo admite tráfico del laboratorio y administración NAT local.
ufw default deny incoming
ufw default allow outgoing
ufw allow in on enp0s3 to any port 22 proto tcp
for port in $LAB_PORTS; do
  ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port "$port" proto tcp
done
ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port 53 proto udp
ufw allow in on "$LAB_IFACE" from "$LAB_NETWORK" to any port 40000:40100 proto tcp
ufw --force enable
# cambiar-ip.sh lee esto para reconstruir el firewall con la misma interfaz y puertos.
printf 'LAB_IFACE=%q\nLAB_PORTS=%q\n' "$LAB_IFACE" "$LAB_PORTS" > /root/lab5-private/red.env
chmod 600 /root/lab5-private/red.env
# Si la VM cambia de red (otro Wi-Fi, hotspot), reconfigura sola zona, ACL, FTP pasivo y UFW (ver red-auto.sh).
bash "$ROOT/virtualbox/instalar-red-auto.sh"
bash "$ROOT/virtualbox/arrancar-servicios.sh"
