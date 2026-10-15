#!/usr/bin/env python3
"""Convierte credentials.json en el users.tsv que pide el instalador de LDAP (ldap/scripts/install.sh).

Sirve para que quien aloja LDAP cargue los MISMOS seis usuarios y claves que usa el resto del grupo (las de credentials.json
de quien administra la zona DNS). No imprime ninguna clave.

  python virtualbox/generar-users-tsv.py --credenciales C:\\ruta\\credentials.json --salida C:\\ruta\\users.tsv

Después, en el equipo Ubuntu de LDAP (copiando users.tsv; la clave del administrador es "admin_password" de credentials.json):
  sudo LDAP_ADMIN_PASSWORD='<admin_password>' USERS_FILE=/ruta/users.tsv ./ldap/scripts/install.sh
Formato de cada fila (separada por tabuladores): uid, cn, sn, mail, clave.
"""
import argparse
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--credenciales', type=Path, required=True)
    ap.add_argument('--salida', type=Path, required=True)
    args = ap.parse_args()
    passwords = json.loads(args.credenciales.read_text(encoding='utf8'))['passwords']
    ldif = (ROOT / 'ldap' / 'ldif' / 'usuarios-laboratorio.ldif').read_text(encoding='utf8')
    filas = []
    for bloque in ldif.split('\n\n'):
        atributos = dict(re.findall(r'^(uid|cn|sn|mail): (.+)$', bloque, re.M))
        if 'uid' in atributos:
            if atributos['uid'] not in passwords:
                raise SystemExit(f"credentials.json no tiene clave para {atributos['uid']}")
            filas.append('\t'.join([atributos[k] for k in ('uid', 'cn', 'sn', 'mail')] + [passwords[atributos['uid']]]))
    args.salida.parent.mkdir(parents=True, exist_ok=True)
    args.salida.write_text('\n'.join(filas) + '\n', encoding='utf8', newline='\n')
    try:
        args.salida.chmod(0o600)
    except OSError:
        pass
    print(f'{len(filas)} usuarios escritos en {args.salida} (contiene claves: entréguelo solo por un canal privado).')


if __name__ == '__main__':
    main()
