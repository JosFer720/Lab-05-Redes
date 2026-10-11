#!/usr/bin/env bash
# Requiere archivos privados fuera del repositorio; no incluye credenciales.
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
source "${PRIVATE_ENV:-/root/lab5-private/deploy.env}"
export DOMAIN=aerolinea.redes.test BASE_DN=dc=aerolinea,dc=redes,dc=test
export DNS_IP=192.168.56.10
export LDAP_IP=$DNS_IP WEB_IP=$DNS_IP MAIL_IP=$DNS_IP FTP_IP=$DNS_IP
export ORG_NAME=AeroQuetzal
export LOCAL_NETWORK=192.168.56.0/24 LDAP_HOST=ldap.aerolinea.redes.test LDAP_PORT=389 PASV_ADDRESS=$DNS_IP
export DEBIAN_FRONTEND=noninteractive
printf '%s\n' 'GRUB_CMDLINE_LINUX_DEFAULT="quiet noapic clocksource=acpi_pm"' > /etc/default/grub.d/99-lab5-timer.cfg
update-grub
# Evitar regenerar la base de sugerencias de comandos en cada apt update.
# Se conserva el archivo original para restaurarlo; no afecta paquetes/servicios.
install -d /var/backups/lab5
if [[ -f /etc/apt/apt.conf.d/50command-not-found ]]; then
  mv /etc/apt/apt.conf.d/50command-not-found /var/backups/lab5/50command-not-found
fi
apt-get update
apt-get install -y curl ca-certificates xz-utils python3 ufw
bash "$ROOT/dns/scripts/install.sh"
install -d /etc/systemd/resolved.conf.d
printf '[Resolve]\nDNS=192.168.56.10\nDomains=~aerolinea.redes.test\n' > /etc/systemd/resolved.conf.d/lab5.conf
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
  curl -fsSL https://nodejs.org/dist/latest-v24.x/SHASUMS256.txt -o "$tmp/SHASUMS256.txt"
  name=$(awk '/node-v24.*-linux-x64.tar.xz$/ {print $2}' "$tmp/SHASUMS256.txt")
  [[ $name == node-v24.*-linux-x64.tar.xz && $name != *$'\n'* ]]
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
for port in 22 53 80 389 25 587 143 21; do
  ufw allow in on enp0s8 from 192.168.56.0/24 to any port "$port" proto tcp
done
ufw allow in on enp0s8 from 192.168.56.0/24 to any port 53 proto udp
ufw allow in on enp0s8 from 192.168.56.0/24 to any port 40000:40100 proto tcp
ufw --force enable
bash "$ROOT/virtualbox/arrancar-servicios.sh"
