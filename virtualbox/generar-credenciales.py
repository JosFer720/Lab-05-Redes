#!/usr/bin/env python3
"""Genera credentials.json con claves aleatorias para el laboratorio (una por integrante, FTP y administrador de LDAP).

Quien aloja los servicios ejecuta esto una sola vez y entrega el archivo a quienes harán de cliente, por un canal
privado (nunca por Git ni por una carpeta compartida). Las claves no se imprimen.

  python virtualbox/generar-credenciales.py            crea <LAB5_PRIVATE_DIR o .git>/lab5-private/credentials.json
  python virtualbox/generar-credenciales.py --forzar   reemplaza el archivo existente
  python virtualbox/generar-credenciales.py --salida C:\\ruta\\credentials.json

Si el repositorio está en una carpeta sincronizada (OneDrive), defina LAB5_PRIVATE_DIR para que los secretos
queden fuera de ella (en .git/ también se sincronizarían).
"""
import argparse
import json
import os
import re
import secrets
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
FALLBACK_USERS = ['fruiz', 'hbarillas', 'icumes', 'jvalladares', 'nmolina', 'mpolanco']


def users():
    ldif = ROOT / 'ldap' / 'ldif' / 'usuarios-laboratorio.ldif'
    if ldif.exists():
        found = re.findall(r'^uid: (\S+)$', ldif.read_text(encoding='utf8'), re.M)
        if found:
            return list(dict.fromkeys(found))
    return FALLBACK_USERS


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--salida', type=Path)
    ap.add_argument('--forzar', action='store_true')
    args = ap.parse_args()
    base = Path(os.environ['LAB5_PRIVATE_DIR']) if os.environ.get('LAB5_PRIVATE_DIR') else ROOT / '.git'
    out = args.salida or base / 'lab5-private' / 'credentials.json'
    if out.exists() and not args.forzar:
        print(f'Ya existe {out}; se conserva (use --forzar para reemplazarlo).')
        return 0
    credentials = {
        'passwords': {uid: secrets.token_urlsafe(24) for uid in users()},
        'ftp_user': 'ftpuser',
        'ftp_password': secrets.token_urlsafe(24),
        'admin_password': secrets.token_urlsafe(24),
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(credentials, indent=2), encoding='utf8', newline='\n')
    try:
        out.chmod(0o600)
    except OSError:
        pass
    print(f'Credenciales nuevas guardadas en {out} ({len(credentials["passwords"])} usuarios + FTP + administrador LDAP).')
    print('Entregue este archivo solo por un canal privado a quien vaya a probar el servidor.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
