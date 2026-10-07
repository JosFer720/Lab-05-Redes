#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

FTP_USER=${FTP_USER:-ftpuser}
FTP_PASSWORD=${FTP_PASSWORD:-}
FTP_ROOT=${FTP_ROOT:-/srv/ftp/${FTP_USER}}
PASV_MIN_PORT=${PASV_MIN_PORT:-40000}
PASV_MAX_PORT=${PASV_MAX_PORT:-40100}
PASV_ADDRESS=${PASV_ADDRESS:-}
NOLOGIN_SHELL=/usr/sbin/nologin

if [[ -z ${FTP_PASSWORD} ]]; then
  echo "Error: defina FTP_PASSWORD con una contraseña exclusiva del laboratorio." >&2
  exit 1
fi
if [[ ! ${FTP_USER} =~ ^[a-z_][a-z0-9_-]*$ ]]; then
  echo "Error: FTP_USER no es un nombre de usuario válido." >&2
  exit 1
fi
if [[ ! ${PASV_MIN_PORT} =~ ^[0-9]+$ || ! ${PASV_MAX_PORT} =~ ^[0-9]+$ ]] ||
   (( PASV_MIN_PORT < 1024 || PASV_MAX_PORT > 65535 || PASV_MIN_PORT > PASV_MAX_PORT )); then
  echo "Error: rango pasivo inválido." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SOURCE_CONFIG=${SCRIPT_DIR}/../config/vsftpd.conf
export DEBIAN_FRONTEND=noninteractive

apt-get update
apt-get install -y vsftpd curl

if getent passwd "${FTP_USER}" >/dev/null; then
  usermod -d "${FTP_ROOT}" -s "${NOLOGIN_SHELL}" "${FTP_USER}"
else
  useradd -m -d "${FTP_ROOT}" -s "${NOLOGIN_SHELL}" "${FTP_USER}"
fi
printf '%s:%s\n' "${FTP_USER}" "${FTP_PASSWORD}" | chpasswd

grep -Fxq "${NOLOGIN_SHELL}" /etc/shells || printf '%s\n' "${NOLOGIN_SHELL}" >> /etc/shells

install -d -o root -g root -m 0755 "${FTP_ROOT}"
install -d -o "${FTP_USER}" -g "${FTP_USER}" -m 0755 "${FTP_ROOT}/uploads"
printf '%s\n' 'archivo de prueba descargable' > "${FTP_ROOT}/bienvenida.txt"
chown root:root "${FTP_ROOT}/bienvenida.txt"
chmod 0644 "${FTP_ROOT}/bienvenida.txt"

if [[ -f /etc/vsftpd.conf ]]; then
  BACKUP=/etc/vsftpd.conf.bak.$(date +%Y%m%d%H%M%S)
  cp -a /etc/vsftpd.conf "${BACKUP}"
  echo "Respaldo creado: ${BACKUP}"
fi

sed -e "s/^pasv_min_port=.*/pasv_min_port=${PASV_MIN_PORT}/" \
    -e "s/^pasv_max_port=.*/pasv_max_port=${PASV_MAX_PORT}/" \
    "${SOURCE_CONFIG}" > /etc/vsftpd.conf
if [[ -n ${PASV_ADDRESS} ]]; then
  printf 'pasv_address=%s\n' "${PASV_ADDRESS}" >> /etc/vsftpd.conf
fi

printf '%s\n' "${FTP_USER}" > /etc/vsftpd.userlist
chmod 0600 /etc/vsftpd.userlist
install -d -o root -g root -m 0755 /var/run/vsftpd/empty
touch /var/log/vsftpd.log

systemctl enable --now vsftpd
systemctl restart vsftpd
systemctl --no-pager --full status vsftpd
echo "FTP instalado. UFW no fue modificado."
