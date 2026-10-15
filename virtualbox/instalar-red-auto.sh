#!/usr/bin/env bash
# Instala el temporizador lab5-red-auto: cada minuto revisa si cambió la red de la VM y, si es así, reconfigura la zona
# (ns1), la ACL de BIND, el FTP pasivo y UFW con la IP nueva, conservando las IPs de los compañeros (ver red-auto.sh).
# Uso, dentro de la VM:   sudo bash /opt/lab5/virtualbox/instalar-red-auto.sh
# Ver lo que hizo:        journalctl -u lab5-red-auto --since today --no-pager     (con -t lab5-red-auto solo salen los avisos de cambio de red)
# Quitarlo:               sudo systemctl disable --now lab5-red-auto.timer
set -Eeuo pipefail
[[ $EUID == 0 ]] || { echo 'Ejecute con sudo' >&2; exit 1; }
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
[[ -f $ROOT/virtualbox/red-auto.sh ]] || { echo "No encuentro $ROOT/virtualbox/red-auto.sh" >&2; exit 1; }

cat > /etc/systemd/system/lab5-red-auto.service <<EOF
[Unit]
Description=Lab5: reconfigurar DNS, firewall y FTP si cambia la red de la VM
After=network-online.target named.service

[Service]
Type=oneshot
ExecStart=/bin/bash $ROOT/virtualbox/red-auto.sh
EOF

cat > /etc/systemd/system/lab5-red-auto.timer <<EOF
[Unit]
Description=Lab5: revisar cada minuto si cambio la red de la VM

[Timer]
OnBootSec=40s
OnUnitActiveSec=60s
AccuracySec=5s

[Install]
WantedBy=timers.target
EOF

systemctl daemon-reload
systemctl enable --now lab5-red-auto.timer
systemctl list-timers lab5-red-auto.timer --no-pager | head -3
echo "Temporizador lab5-red-auto instalado: si cambia la IP o la red, la VM se reconfigura sola en menos de un minuto."
