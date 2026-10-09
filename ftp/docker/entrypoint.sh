#!/usr/bin/env bash
set -Eeuo pipefail

FTP_USER=${FTP_USER:-ftpuser}
FTP_PASSWORD=${FTP_PASSWORD:?Debe definir FTP_PASSWORD}
PASV_ADDRESS=${PASV_ADDRESS:-127.0.0.1}
FTP_ROOT=/srv/ftp/${FTP_USER}

if getent passwd "${FTP_USER}" >/dev/null; then
  usermod -d "${FTP_ROOT}" -s /usr/sbin/nologin "${FTP_USER}"
else
  useradd -m -d "${FTP_ROOT}" -s /usr/sbin/nologin "${FTP_USER}"
fi

printf '%s:%s\n' "${FTP_USER}" "${FTP_PASSWORD}" | chpasswd
grep -Fxq /usr/sbin/nologin /etc/shells || printf '%s\n' /usr/sbin/nologin >> /etc/shells

install -d -o root -g root -m 0755 "${FTP_ROOT}"
install -d -o "${FTP_USER}" -g "${FTP_USER}" -m 0755 "${FTP_ROOT}/uploads"
install -d -o root -g root -m 0555 /var/run/vsftpd/empty
printf '%s\n' 'archivo de prueba descargable' > "${FTP_ROOT}/bienvenida.txt"
chown root:root "${FTP_ROOT}/bienvenida.txt"
printf '%s\n' "${FTP_USER}" > /etc/vsftpd.userlist
sed -i "s/^pasv_address=.*/pasv_address=${PASV_ADDRESS}/" /etc/vsftpd.conf

while true; do
  /usr/sbin/vsftpd /etc/vsftpd.conf
  sleep 0.1
done
