#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

FTP_ACCOUNTS=${FTP_ACCOUNTS:-$'ian:IanLab5\njavier:JavierLab5\nfernando:FernandoLab5\nnery:NeryLab5\nhugo:HugoLab5\nmilton:MiltonLab5\nguest:GuestLab5'}
PASV_MIN_PORT=${PASV_MIN_PORT:-40000}
PASV_MAX_PORT=${PASV_MAX_PORT:-40100}
PASV_ADDRESS=${PASV_ADDRESS:-}
NOLOGIN_SHELL=/usr/sbin/nologin

if [[ -z ${FTP_ACCOUNTS} ]]; then
  echo "Error: FTP_ACCOUNTS no puede estar vacío." >&2
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

grep -Fxq "${NOLOGIN_SHELL}" /etc/shells || printf '%s\n' "${NOLOGIN_SHELL}" >> /etc/shells

create_ftp_account() {
  local user=$1 password=$2 root=$3
  if getent passwd "${user}" >/dev/null; then
    usermod -d "${root}" -s "${NOLOGIN_SHELL}" "${user}"
  else
    useradd -M -d "${root}" -s "${NOLOGIN_SHELL}" "${user}"
  fi
  printf '%s:%s\n' "${user}" "${password}" | chpasswd
  install -d -o root -g root -m 0755 "${root}"
  install -d -o "${user}" -g "${user}" -m 0755 "${root}/uploads"
  printf '%s\n' 'archivo de prueba descargable' > "${root}/bienvenida.txt"
  chown root:root "${root}/bienvenida.txt"
  chmod 0644 "${root}/bienvenida.txt"
}

FTP_USERS=()
while IFS=: read -r user password extra; do
  if [[ -z ${user} || -z ${password} || -n ${extra:-} || ! ${user} =~ ^[a-z_][a-z0-9_-]*$ ]]; then
    echo "Error: cuenta FTP inválida para ${user:-valor-vacío}." >&2
    exit 1
  fi
  create_ftp_account "${user}" "${password}" "/srv/ftp/${user}"
  FTP_USERS+=("${user}")
done <<< "${FTP_ACCOUNTS}"

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

printf '%s\n' "${FTP_USERS[@]}" > /etc/vsftpd.userlist
chmod 0600 /etc/vsftpd.userlist
install -d -o root -g root -m 0755 /var/run/vsftpd/empty
touch /var/log/vsftpd.log

systemctl enable --now vsftpd
systemctl restart vsftpd
systemctl --no-pager --full status vsftpd
echo "FTP instalado. UFW no fue modificado."
