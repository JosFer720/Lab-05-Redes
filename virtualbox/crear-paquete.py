#!/usr/bin/env python3
"""Crea un .zip con lo necesario para levantar el laboratorio en otra computadora, sin .git ni secretos.

Sirve para pasarle a un compañero los scripts de modo puente cuando todavía no están en el repositorio remoto.
Incluye dns, ldap, web (con el sitio ya compilado en web/site/dist, si existe), mail, ftp, client, virtualbox, shared
y README.md; excluye node_modules, .git, claves (.env, credentials.json, id_rsa...) y evidencias. Los archivos de texto
se empaquetan con saltos de línea LF.

  python virtualbox/crear-paquete.py                      -> ../Lab5-paquete.zip
  python virtualbox/crear-paquete.py --salida C:\\ruta\\paquete.zip
"""
import argparse
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
INCLUDE_DIRS = ['dns', 'ldap', 'web', 'mail', 'ftp', 'client', 'virtualbox', 'shared']
INCLUDE_FILES = ['README.md', '.gitattributes']
SKIP_PARTS = {'node_modules', '__pycache__', '.venv', 'dist', '.git', '.vscode'}
SITIO_COMPILADO = ('web', 'site', 'dist')
SECRET_NAMES = {'credentials.json', 'id_rsa', 'id_rsa.openssh', 'id_rsa.pub', 'known_hosts', 'users.tsv', 'deploy.env'}
KEEP_CRLF = {'.ps1', '.bat', '.cmd'}
CRLF = bytes([13, 10])
LF = bytes([10])
NUL = bytes([0])


def wanted(path):
    rel = path.relative_to(ROOT)
    # El sitio ya compilado (web/site/dist) SÍ va: permite instalar Apache con web/scripts/install.sh sin Node ni Internet.
    partes = rel.parts[3:] if rel.parts[:3] == SITIO_COMPILADO else rel.parts
    if any(part in SKIP_PARTS for part in partes) or path.suffix in {'.pyc', '.log', '.bak', '.iso', '.vdi', '.vmdk'}:
        return False
    if path.name in SECRET_NAMES:
        return False
    if path.suffix == '.env' and path.name != 'lab.example.env':
        return False
    return path.is_file()


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--salida', type=Path, default=ROOT.parent / 'Lab5-paquete.zip')
    args = ap.parse_args()
    files = [ROOT / name for name in INCLUDE_FILES if (ROOT / name).is_file()]
    for directory in INCLUDE_DIRS:
        files += sorted(p for p in (ROOT / directory).rglob('*') if wanted(p))
    converted = 0
    with zipfile.ZipFile(args.salida, 'w', zipfile.ZIP_DEFLATED) as z:
        for path in files:
            name = 'Lab-05-Redes/' + path.relative_to(ROOT).as_posix()
            data = path.read_bytes()
            # Con Git en Windows (autocrlf) los archivos de texto salen con CRLF y en Linux fallan
            # (por ejemplo vsftpd.conf deja de arrancar): se empaquetan con LF. Los .ps1 se dejan tal cual.
            if NUL not in data and CRLF in data and path.suffix.lower() not in KEEP_CRLF:
                data = re.sub(rb'\r+\n', LF, data)      # también limpia finales mezclados como CR CR LF
                converted += 1
            z.writestr(name, data)
    size = args.salida.stat().st_size / 1024 / 1024
    print(f'{len(files)} archivos, {size:.1f} MB -> {args.salida} ({converted} convertidos de CRLF a LF)')
    sitio = sum(1 for p in files if p.relative_to(ROOT).parts[:3] == SITIO_COMPILADO)
    print(f'Sitio web compilado (web/site/dist): {sitio} archivos' if sitio else
          'AVISO: no hay web/site/dist; compile el sitio (npm run build en web/site) antes de empaquetar si el paquete debe instalarse sin Internet.')
    print('No contiene claves ni credenciales: las credenciales se generan o entregan aparte.')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
