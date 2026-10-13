#!/usr/bin/env python3
"""Evidencia LDAP-01 a LDAP-04 desde un cliente Windows (ldap3), con salida parecida a ldapsearch/ldapwhoami.

Uso: python client/windows/ldap-evidencia.py --server <IP-del-servidor> --credentials <credentials.json> [--user icumes]
Resuelve ldap.aerolinea.redes.test con el DNS del sistema (client/windows/cliente.ps1 dns-on); si no resuelve
se conecta a la IP del servidor y lo indica. La contrasena nunca se imprime.
"""
import argparse
import json
import socket
import sys
from pathlib import Path

import ldap3

sys.stdout.reconfigure(encoding='utf8', errors='replace')
HOST = 'ldap.aerolinea.redes.test'
BASE = 'dc=aerolinea,dc=redes,dc=test'
PEOPLE = 'ou=People,' + BASE
ATTRS = ['uid', 'cn', 'sn', 'mail']


def target(server_ip):
    try:
        ip = socket.gethostbyname(HOST)
        return ip, f'{HOST} -> {ip} (DNS del sistema)'
    except OSError:
        return server_ip, f'{HOST} no resuelve con el DNS del sistema: se usa la IP {server_ip} (ejecute cliente.ps1 dns-on)'


def connect(ip, dn=None, password=None):
    server = ldap3.Server(ip, port=389, get_info=ldap3.NONE, connect_timeout=5)
    auth = ldap3.SIMPLE if dn else ldap3.ANONYMOUS
    return ldap3.Connection(server, user=dn, password=password, authentication=auth, receive_timeout=10)


def entry_text(entry):
    lines = ['dn: ' + entry.entry_dn]
    for name in ATTRS:
        for value in entry[name].values if name in entry else []:
            lines.append(f'{name}: {value}')
    return '\n'.join(lines)


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--server', required=True)
    ap.add_argument('--credentials', type=Path, required=True)
    ap.add_argument('--user', default='icumes')
    args = ap.parse_args()
    passwords = json.loads(args.credentials.read_text(encoding='utf8'))['passwords']
    if args.user not in passwords:
        raise SystemExit(f'El usuario {args.user} no esta en el archivo de credenciales: {", ".join(passwords)}')
    ip, how = target(args.server)
    dn = f'uid={args.user},{PEOPLE}'
    failures = 0
    print(f'Servidor LDAP: {how}\n')

    print(f'### LDAP-01  ldapsearch -x -LLL -H ldap://{HOST} -b {PEOPLE} "(objectClass=inetOrgPerson)" uid cn sn mail')
    c = connect(ip)
    if not c.bind():
        print('FALLA: no se pudo conectar a LDAP:', c.result)
        return 1
    c.search(PEOPLE, '(objectClass=inetOrgPerson)', attributes=ATTRS)
    for e in c.entries:
        print(entry_text(e) + '\n')
    print(f'# {len(c.entries)} usuarios encontrados')
    if len(c.entries) < 6:
        failures += 1
        print('FALLA: se esperaban al menos 6 usuarios (uno por integrante)')
    c.unbind()

    print(f'\n### LDAP-02  ldapwhoami -x -H ldap://{HOST} -D {dn} -w ********   (contrasena correcta)')
    c = connect(ip, dn, passwords[args.user])
    if c.bind():
        print('dn:' + dn + '\nResultado: exito (0) - autenticacion aceptada')
        c.unbind()
    else:
        failures += 1
        print('FALLA: la contrasena correcta fue rechazada:', c.result['description'])

    print(f'\n### LDAP-03  ldapwhoami -x -H ldap://{HOST} -D {dn} -w ********   (contrasena incorrecta)')
    c = connect(ip, dn, 'contrasena-incorrecta')
    if c.bind():
        failures += 1
        print('FALLA: se acepto una contrasena incorrecta')
        c.unbind()
    else:
        print(f'ldap_bind: Invalid credentials ({c.result["result"]})  <- rechazo esperado (49)')

    print(f'\n### LDAP-03b usuario inexistente')
    c = connect(ip, f'uid=noexiste,{PEOPLE}', 'x')
    if c.bind():
        failures += 1
        print('FALLA: se acepto un usuario inexistente')
        c.unbind()
    else:
        print(f'ldap_bind: Invalid credentials ({c.result["result"]})  <- rechazo esperado (49)')

    print(f'\n### LDAP-04  ldapsearch -x -LLL -H ldap://{HOST} -b {PEOPLE} "(uid={args.user})" uid cn sn mail')
    c = connect(ip)
    c.bind()
    c.search(PEOPLE, f'(uid={args.user})', attributes=ATTRS)
    for e in c.entries:
        print(entry_text(e))
    faltan = [a for a in ATTRS if not c.entries or a not in c.entries[0]]
    if faltan:
        failures += 1
        print('FALLA: faltan atributos', faltan)
    c.search(PEOPLE, f'(uid={args.user})', attributes=['userPassword'])
    # ldap3 crea el atributo vacio aunque el servidor no lo devuelva: se mira el valor, no la presencia.
    oculto = not any(r.get('attributes', {}).get('userPassword') for r in c.response if r.get('type') == 'searchResEntry')
    print('\n# userPassword visible para una consulta anonima: ' + ('NO (correcto, oculto por ACL)' if oculto else 'SI (revisar ACL)'))
    c.unbind()

    print('\nRESULTADO:', 'todo correcto' if not failures else f'{failures} fallas')
    return 1 if failures else 0


if __name__ == '__main__':
    raise SystemExit(main())
