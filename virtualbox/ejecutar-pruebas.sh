#!/usr/bin/env bash
set -Eeuo pipefail
ROOT=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
export DNS_SERVER=${DNS_SERVER:-192.168.56.10}
export ZONE_FILE=/etc/bind/zones/db.aerolinea.redes.test
python3 "$ROOT/client/tests/test-official.py" --credentials "${CREDENTIALS_FILE:-/root/lab5-private/credentials.json}" --output "${RESULTS_FILE:-/var/log/lab5-official.json}" --scope 'Ubuntu 24.04 nativo, VirtualBox; pruebas locales del servidor'
