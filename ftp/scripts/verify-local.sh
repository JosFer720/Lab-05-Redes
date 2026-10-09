#!/usr/bin/env bash
set -Eeuo pipefail

FTP_USER=${FTP_USER:-fernando}
FTP_ROOT=${FTP_ROOT:-/srv/ftp/${FTP_USER}}
FTP_GUEST_USER=${FTP_GUEST_USER:-guest}
FTP_GUEST_ROOT=${FTP_GUEST_ROOT:-/srv/ftp/${FTP_GUEST_USER}}
FTP_USERS=${FTP_USERS:-ian javier fernando nery hugo milton guest}
failed=0

check() {
  local description=$1
  shift
  if "$@"; then
    printf '[PASS] %s\n' "${description}"
  else
    printf '[FAIL] %s\n' "${description}" >&2
    failed=1
  fi
}

check 'servicio activo' systemctl is-active --quiet vsftpd
check 'servicio habilitado al arranque' systemctl is-enabled --quiet vsftpd
check 'puerto de control 21 escuchando' bash -c "ss -lnt | grep -Eq '[:.]21[[:space:]]'"
check 'usuario en lista permitida' grep -Fxq "${FTP_USER}" /etc/vsftpd.userlist
check 'invitado en lista permitida' grep -Fxq "${FTP_GUEST_USER}" /etc/vsftpd.userlist
check 'raíz propiedad de root' bash -c "[[ \$(stat -c '%U:%G' '${FTP_ROOT}') == root:root ]]"
check 'raíz no escribible por usuario' bash -c "! su -s /bin/sh -c 'test -w \"${FTP_ROOT}\"' '${FTP_USER}'"
check 'uploads escribible por usuario' bash -c "su -s /bin/sh -c 'test -w \"${FTP_ROOT}/uploads\"' '${FTP_USER}'"
check 'raíz invitada propiedad de root' bash -c "[[ \$(stat -c '%U:%G' '${FTP_GUEST_ROOT}') == root:root ]]"
check 'uploads escribible por invitado' bash -c "su -s /bin/sh -c 'test -w \"${FTP_GUEST_ROOT}/uploads\"' '${FTP_GUEST_USER}'"
for user in ${FTP_USERS}; do
  check "cuenta ${user} permitida" grep -Fxq "${user}" /etc/vsftpd.userlist
  check "directorio ${user} disponible" test -d "/srv/ftp/${user}/uploads"
done
check 'anónimo deshabilitado' grep -Fxq 'anonymous_enable=NO' /etc/vsftpd.conf
check 'chroot habilitado' grep -Fxq 'chroot_local_user=YES' /etc/vsftpd.conf
check 'log habilitado' grep -Fxq 'log_ftp_protocol=YES' /etc/vsftpd.conf

exit "${failed}"
