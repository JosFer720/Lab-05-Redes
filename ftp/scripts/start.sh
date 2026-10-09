#!/usr/bin/env bash
set -Eeuo pipefail

if [[ ${EUID} -ne 0 ]]; then
  echo "Error: ejecute este script con sudo." >&2
  exit 1
fi

SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
FTP_USER=${FTP_USER:-fernando}
FTP_PASSWORD=${FTP_PASSWORD:-FernandoLab5}
FTP_GUEST_USER=${FTP_GUEST_USER:-guest}
FTP_GUEST_PASSWORD=${FTP_GUEST_PASSWORD:-GuestLab5}
FTP_ACCOUNTS=${FTP_ACCOUNTS:-$'ian:IanLab5\njavier:JavierLab5\nfernando:FernandoLab5\nnery:NeryLab5\nhugo:HugoLab5\nmilton:MiltonLab5\nguest:GuestLab5'}
export FTP_USER FTP_PASSWORD FTP_GUEST_USER FTP_GUEST_PASSWORD FTP_ACCOUNTS

FTP_READY=1
if ! command -v vsftpd >/dev/null 2>&1 ||
   ! grep -Fxq 'chroot_local_user=YES' /etc/vsftpd.conf 2>/dev/null; then
  FTP_READY=0
fi
for user in ian javier fernando nery hugo milton guest; do
  if ! grep -Fxq "${user}" /etc/vsftpd.userlist 2>/dev/null; then
    FTP_READY=0
  fi
done

if (( FTP_READY == 0 )); then
  echo "FTP no está configurado. Ejecutando instalación inicial."
  "${SCRIPT_DIR}/install.sh"
else
  systemctl enable vsftpd
  systemctl restart vsftpd
fi

"${SCRIPT_DIR}/verify-local.sh"
echo "FTP disponible en el puerto 21 y en el rango pasivo configurado."
echo "FTP habilitado para ian, javier, fernando, nery, hugo, milton y guest."
echo "Cada cuenta utiliza la misma clave configurada en LDAP."
