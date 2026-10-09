#!/usr/bin/env python3
"""Matriz LDAP del laboratorio, ejecutada desde otra VM mediante DNS real."""
import argparse
import datetime
import json
import os
from pathlib import Path
import subprocess
import tempfile

USERS = {
    'fruiz': ('Fernando Ruiz', 'Ruiz'),
    'hbarillas': ('Hugo Barillas', 'Barillas'),
    'icumes': ('Ian Cumes', 'Cumes'),
    'jvalladares': ('Javier Valladares', 'Valladares'),
    'nmolina': ('Nery Molina', 'Molina'),
    'mpolanco': ('Milton Polanco', 'Polanco'),
}

def run(*args):
    try:
        result = subprocess.run(args, capture_output=True, text=True, timeout=15)
        return result.returncode, result.stdout + result.stderr
    except subprocess.TimeoutExpired:
        return 124, 'ERROR: tiempo de espera agotado\n'

def entries(text):
    parsed = []
    for block in text.split('\n\n'):
        item = {}
        for line in block.splitlines():
            if ': ' in line and not line.startswith('#'):
                key, value = line.split(': ', 1)
                item[key] = value
        if 'uid' in item:
            parsed.append(item)
    return parsed

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--host', default='ldap.aerolinea.redes.test')
    parser.add_argument('--port', type=int, default=389)
    parser.add_argument('--dns-server', default='192.168.50.10')
    parser.add_argument('--expected-ip', default='192.168.50.11')
    parser.add_argument('--base', default='dc=aerolinea,dc=redes,dc=test')
    parser.add_argument('--credentials', type=Path, default=Path.home()/'.lab5-ldap-users.json')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    passwords = json.loads(args.credentials.read_text())
    args.output.mkdir(parents=True, exist_ok=True)
    result_list = []
    uri = f'ldap://{args.host}:{args.port}'
    people = 'ou=People,' + args.base
    now = datetime.datetime.now(datetime.timezone.utc).isoformat()

    def record(test_id, description, passed, text):
        status = 'PASS' if passed else 'FAIL'
        (args.output/(test_id+'.txt')).write_text(f'{now}\n{description}\n{status}\n\n{text}')
        result_list.append({'id': test_id, 'description': description, 'status': status})
        print(f'{test_id}: {status} - {description}', flush=True)

    code, text = run('dig', '+short', args.host, 'A')
    record('INT-01-DNS-LDAP', 'Nombre LDAP resuelto por el DNS de la VM cliente', code == 0 and text.strip() == args.expected_ip, text)
    code, text = run('resolvectl', 'dns', 'eth0')
    dns_servers = text.split(':', 1)[1].split() if ':' in text else []
    record('INT-01-RESOLVER', f'Cliente utiliza DNS {args.dns_server}', code == 0 and dns_servers == [args.dns_server], text)
    common = ['-x', '-o', 'nettimeout=5', '-H', uri]
    code, text = run('ldapsearch', *common, '-LLL', '-b', people, '(objectClass=inetOrgPerson)', 'uid', 'cn', 'sn', 'mail')
    found = entries(text)
    record('LDAP-01', 'Exactamente los seis integrantes dentro de ou=People', code == 0 and len(found) == len(USERS) and {x['uid'] for x in found} == set(USERS), text)

    def bind(uid, password):
        with tempfile.NamedTemporaryFile(mode='w', prefix='lab5-bind-') as secret:
            os.chmod(secret.name, 0o600)
            secret.write(password)
            secret.flush()
            return run('ldapwhoami', *common, '-D', f'uid={uid},{people}', '-y', secret.name)

    for uid in USERS:
        code, text = bind(uid, passwords[uid])
        record('LDAP-02-'+uid, f'Bind válido de {uid}', code == 0 and text.strip() == f'dn:uid={uid},{people}', text)
    code, text = bind('jvalladares', 'clave-incorrecta-laboratorio')
    record('LDAP-03', 'Contraseña incorrecta rechazada con código LDAP 49', code == 49 and 'Invalid credentials (49)' in text, text)
    code, text = bind('noexiste', 'clave-incorrecta-laboratorio')
    record('LDAP-03-USUARIO-INEXISTENTE', 'Usuario inexistente rechazado con código LDAP 49', code == 49 and 'Invalid credentials (49)' in text, text)
    all_attributes = True
    for entry in found:
        uid = entry['uid']
        if uid not in USERS:
            all_attributes = False
            continue
        cn, sn = USERS[uid]
        expected = {'dn': f'uid={uid},{people}', 'uid': uid, 'cn': cn, 'sn': sn, 'mail': f'{uid}@aerolinea.redes.test'}
        all_attributes &= all(entry.get(k) == v for k,v in expected.items())
    code, text = run('ldapsearch', *common, '-LLL', '-b', people, '(objectClass=inetOrgPerson)', 'uid', 'cn', 'sn', 'mail')
    record('LDAP-04', 'uid, cn, sn y mail correctos en las seis cuentas', code == 0 and len(found) == len(USERS) and all_attributes, text)
    code, text = run('ldapsearch', *common, '-LLL', '-b', people, '(objectClass=inetOrgPerson)', 'uid', 'userPassword')
    record('ACL-PASSWORD-ANONIMO', 'Búsqueda anónima no expone userPassword', code == 0 and len(entries(text)) == len(USERS) and 'userPassword:' not in text, text)
    with tempfile.NamedTemporaryFile(mode='w') as secret:
        os.chmod(secret.name, 0o600)
        secret.write(passwords['fruiz'])
        secret.flush()
        code, text = run('ldapsearch', *common, '-D', f'uid=fruiz,{people}', '-y', secret.name, '-LLL', '-b', f'uid=hbarillas,{people}', '-s', 'base', '(objectClass=*)', 'uid', 'userPassword')
    record('ACL-PASSWORD-OTRO-USUARIO', 'Usuario autenticado no lee el hash de otra cuenta', code == 0 and 'uid: hbarillas' in text and 'userPassword:' not in text, text)
    (args.output/'matriz.json').write_text(json.dumps({'date': now, 'host': args.host, 'port': args.port, 'dns_server': args.dns_server, 'base': args.base, 'results': result_list}, indent=2, ensure_ascii=False)+'\n')
    return 0 if all(x['status'] == 'PASS' for x in result_list) else 1

if __name__ == '__main__':
    raise SystemExit(main())
