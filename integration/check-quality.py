#!/usr/bin/env python3
"""Verifica sintaxis, configuración y ausencia de secretos en archivos de entrega."""
from pathlib import Path
import base64
import datetime as dt
import json
import subprocess
import sys

ROOT=Path(__file__).resolve().parent.parent
lines=['Fecha UTC: '+dt.datetime.now(dt.timezone.utc).isoformat(), 'Máquina: NERY; checks ejecutados; alcance local']
failed=False
def check(name,command,input=None,expected=0):
    global failed
    p=subprocess.run(command,cwd=ROOT,input=input.encode('utf-8') if input is not None else None,capture_output=True,timeout=180)
    stdout=p.stdout.decode('utf-8',errors='replace'); stderr=p.stderr.decode('utf-8',errors='replace')
    passed=p.returncode==expected
    failed |= not passed
    lines.append(('PASS ' if passed else 'FAIL ')+name+'\n'+stdout+stderr)
    print(('PASS ' if passed else 'FAIL ')+name,flush=True)
    return passed

compose=['docker','compose','-f','integration/docker-compose.yml']
check('BIND named-checkconf',compose+['exec','-T','dns','named-checkconf'])
check('Zona Docker named-checkzone',compose+['exec','-T','dns','named-checkzone','aerolinea.redes.test','/etc/bind/db.aerolinea.redes.test'])
check('Zona histórica (sintaxis; IP históricas no comprobadas)', ['docker','run','--rm','--mount','type=bind,src='+str(ROOT/'dns/zones')+',dst=/zones,readonly','--entrypoint','named-checkzone','lab05-entrega-dns','aerolinea.redes.test','/zones/db.aerolinea.redes.test'])
check('Apache configuración',compose+['exec','-T','web','apache2ctl','configtest'])
check('Postfix check',compose+['exec','-T','mail','postfix','check'])
check('Dovecot configuración',compose+['exec','-T','mail','doveconf','-n'])
check('Apache variante LDAP 1389 (configuración, no servidor remoto)', ['docker','run','--rm','-i','--entrypoint','bash','lab05-entrega-web'],
      "set -e\nsed -i 's|ldap.aerolinea.redes.test/|ldap.aerolinea.redes.test:1389/|' /etc/apache2/sites-available/aerolinea.conf\napache2ctl configtest\n")
check('Postfix/Dovecot variante LDAP 1389 (configuración, no servidor remoto)', ['docker','run','--rm','-i','--entrypoint','bash','lab05-entrega-mail'],
      "set -e\nsed -i 's|ldap.aerolinea.redes.test|ldap.aerolinea.redes.test:1389|' /etc/postfix/ldap-virtual-mailbox.cf /etc/dovecot/dovecot-ldap.conf.ext\npostfix check\ndoveconf -n >/dev/null\n")
scripts=[str(p.relative_to(ROOT)).replace('\\','/') for p in ROOT.rglob('*.sh') if '.git' not in p.parts]
for script in scripts:
    check('Bash -n '+script, ['docker','run','--rm','--mount','type=bind,src='+str(ROOT)+',dst=/repo,readonly','--entrypoint','bash','lab05-entrega-client','-n','/repo/'+script])
ps="""$ErrorActionPreference='Stop'
$bad=$false
Get-ChildItem -Recurse -Filter *.ps1 | Where-Object { -not $_.FullName.Contains('.git') } | ForEach-Object {
 $tokens=$null; $errors=$null
 [System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$tokens,[ref]$errors) | Out-Null
 if ($errors.Count) { $bad=$true; $errors } else { 'PASS '+$_.Name }
}
if($bad){exit 1}
"""
check('PowerShell parser todos los scripts', ['powershell','-NoProfile','-Command',ps])
for filename in ['client/tests/test-official.py','integration/audit-run.py','integration/check-quality.py','docs/reporte/generar-reporte.py']:
    try: compile((ROOT/filename).read_text(encoding='utf8'),filename,'exec'); lines.append('PASS Python sintaxis '+filename)
    except SyntaxError as exc: failed=True; lines.append('FAIL '+str(exc))
check('Compose configuración',compose+['config','--quiet'])
check('Git diff HEAD --check (incluye índice)',['git','diff','HEAD','--check'])
secret_path=ROOT/'.git/lab5-private/credentials.json'
credentials=json.loads(secret_path.read_text())
secret_values=[*credentials['passwords'].values(),credentials['ftp_password'],credentials['admin_password']]
values=secret_values+[base64.b64encode(s.encode()).decode() for s in secret_values]
changed=subprocess.run(['git','diff','--name-only','HEAD'],cwd=ROOT,capture_output=True,text=True).stdout.splitlines()
new=subprocess.run(['git','ls-files','--others','--exclude-standard'],cwd=ROOT,capture_output=True,text=True).stdout.splitlines()
leaks=[]
for filename in set(changed+new):
    p=ROOT/filename
    if p.is_file() and any(v.encode() in p.read_bytes() for v in values): leaks.append(filename)
lines.append(('FAIL' if leaks else 'PASS')+' búsqueda de claves nuevas y base64 en cambios/evidencias: '+str(leaks))
failed |= bool(leaks)
net=json.loads((ROOT/'docs/evidencias/integration/actual/interfaces-contenedores.json').read_text())
macs=[next(iter(n.values()))['MacAddress'] for n in net.values()]
valid=len(set(macs))==6 and all(int(m.split(':')[0],16)&3==2 for m in macs)
lines.append(('PASS' if valid else 'FAIL')+' seis MAC únicas unicast locales: '+str(macs))
failed |= not valid
(ROOT/'docs/evidencias/integration/actual/calidad.txt').write_text('\n'.join(line.rstrip() for line in '\n'.join(lines).splitlines()).rstrip()+'\n',encoding='utf-8')
raise SystemExit(1 if failed else 0)
