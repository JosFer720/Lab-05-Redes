#!/usr/bin/env python3
"""Auditoría Docker reproducible. Secretos locales en .git/lab5-private; sin publicar.

Uso: python integration/audit-run.py
Reinicia solo el proyecto Compose lab05-entrega. No toca Windows DNS/firewall ni VMs.
"""
import base64
import datetime as dt
import hashlib
import json
from pathlib import Path
import re
import secrets
import subprocess
import time
import urllib.parse

ROOT=Path(__file__).resolve().parent.parent
PRIVATE=ROOT/'.git/lab5-private'
EVIDENCE=ROOT/'docs/evidencias/integration/actual'
PRIVATE.mkdir(parents=True,exist_ok=True)
EVIDENCE.mkdir(parents=True,exist_ok=True)
secret_file=PRIVATE/'credentials.json'
if secret_file.exists():
    credentials=json.loads(secret_file.read_text())
else:
    credentials={'passwords':{u:secrets.token_urlsafe(24) for u in ['fruiz','hbarillas','icumes','jvalladares','nmolina','mpolanco']},
                 'ftp_user':'ftpuser','ftp_password':secrets.token_urlsafe(24),'admin_password':secrets.token_urlsafe(24)}
    secret_file.write_text(json.dumps(credentials))
override=PRIVATE/'compose.private.json'
override.write_text(json.dumps({'services':{'ftp':{'environment':{'FTP_PASSWORD':credentials['ftp_password']}}}}))
COMPOSE=['docker','compose','-f',str(ROOT/'integration/docker-compose.yml'),'-f',str(override)]

def clean(text):
    for secret in [*credentials['passwords'].values(),credentials['ftp_password'],credentials['admin_password']]:
        text=text.replace(secret,'[REDACTED]')
    # SMTP AUTH trace contains reversible base64; omit it and credentials from fixtures.
    text=re.sub(r'^.*(?:AUTH (?:LOGIN|PLAIN)|-> [A-Za-z0-9+/=]{8,}\s*$).*$', '[AUTH REDACTED]',text,flags=re.M)
    return text

def run(args,input=None,check=True,timeout=240):
    p=subprocess.run(args,cwd=ROOT,input=input,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    if check and p.returncode:
        raise RuntimeError(clean(p.stdout+p.stderr)[-3500:])
    return p

def execute(service,*args,input=None,check=True):
    return run([*COMPOSE,'exec','-T',service,*args],input=input,check=check)

def save(name,text):
    if name.endswith('.json'):
        (EVIDENCE/name).write_text(text,encoding='utf-8')
        return
    normalized='\n'.join(line.rstrip() for line in clean(text).splitlines()).rstrip()+'\n'
    (EVIDENCE/name).write_text('Fecha UTC: '+dt.datetime.now(dt.timezone.utc).isoformat()+'\n'+normalized,encoding='utf-8')

def ssha(password):
    salt=secrets.token_bytes(8)
    return '{SSHA}'+base64.b64encode(hashlib.sha1(password.encode()+salt).digest()+salt).decode()

def main():
    print('Construcción y disponibilidad de servicios',flush=True)
    p=run([*COMPOSE,'up','-d','--build','--wait','--wait-timeout','180'],timeout=600)
    save('arranque.txt',p.stdout+p.stderr)
    # Respaldo LDIF privado: contiene hashes y configuración, nunca se incorpora a evidencias públicas.
    for n in [0,1]:
        p=execute('ldap','slapcat','-n',str(n))
        first_backup=PRIVATE/f'ldap-before-{n}.ldif'
        if not first_backup.exists(): first_backup.write_text(p.stdout)
        (PRIVATE/f'ldap-before-{dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%S")}-{n}.ldif').write_text(p.stdout)
    database=execute('ldap','ldapsearch','-Q','-Y','EXTERNAL','-H','ldapi:///','-LLL','-b','cn=config','(olcSuffix=dc=aerolinea,dc=redes,dc=test)','dn').stdout
    db_dn=re.search(r'^dn: (.+)$',database,re.M)[1]
    execute('ldap','ldapmodify','-Q','-Y','EXTERNAL','-H','ldapi:///',input=f'dn: {db_dn}\nchangetype: modify\nreplace: olcRootPW\nolcRootPW: {ssha(credentials["admin_password"])}\n')
    # Leer clave por archivo privado, no por argumentos del proceso LDAP.
    execute('ldap','sh','-c','umask 077; cat > /tmp/lab5-admin-password',input=credentials['admin_password'])
    options=['-x','-H','ldap://127.0.0.1','-D','cn=admin,dc=aerolinea,dc=redes,dc=test','-y','/tmp/lab5-admin-password']
    try:
        ldif=(ROOT/'ldap/ldif/usuarios-laboratorio.ldif').read_text()
        for uid,password in credentials['passwords'].items():
            block=next(b for b in ldif.split('\n\n') if '\nuid: '+uid+'\n' in '\n'+b+'\n')
            block=re.sub(r'^userPassword:.*$', 'userPassword: '+ssha(password),block,flags=re.M)
            dn=re.search(r'^dn: (.*)$',block,re.M)[1]
            p=execute('ldap','ldapsearch',*options,'-LLL','-b',dn,'-s','base','dn',check=False)
            if p.returncode==32:
                execute('ldap','ldapadd',*options,input=block+'\n')
            elif p.returncode==0:
                execute('ldap','ldapmodify',*options,input=f'dn: {dn}\nchangetype: modify\nreplace: userPassword\nuserPassword: {ssha(password)}\n')
            else: raise RuntimeError(p.stderr)
        export=execute('ldap','ldapsearch',*options,'-LLL','-b','ou=People,dc=aerolinea,dc=redes,dc=test','(|'+''.join('(uid='+u+')' for u in credentials['passwords'])+')','uid','cn','sn','mail','userPassword').stdout
        (PRIVATE/'usuarios-rotados.ldif').write_text(export)
    finally:
        execute('ldap','rm','-f','/tmp/lab5-admin-password')
    # Copiar credenciales fuera de imagen y eliminarlas en finally.
    client_id=run([*COMPOSE,'ps','-q','client']).stdout.strip()
    run(['docker','cp',str(secret_file),client_id+':/tmp/lab5-credentials.json'])
    execute('client','chmod','600','/tmp/lab5-credentials.json')
    try:
        print('Matriz de protocolos y seis cuentas',flush=True)
        env={'LDAP_USER':'nmolina','LDAP_PASSWORD':credentials['passwords']['nmolina'],
             'WEB_USER':'nmolina','WEB_PASSWORD':credentials['passwords']['nmolina'],
             'MAIL_USER':'nmolina','MAIL_PASSWORD':credentials['passwords']['nmolina'],
             'MAIL_RECIPIENT':'jvalladares@aerolinea.redes.test','MAIL_RECIPIENT_USER':'jvalladares',
             'MAIL_RECIPIENT_PASSWORD':credentials['passwords']['jvalladares'],
             'FTP_USER':credentials['ftp_user'],'FTP_PASSWORD':credentials['ftp_password']}
        command=[*COMPOSE,'exec','-T']
        for key,value in env.items(): command+=['-e',key+'='+value]
        suite=run([*command,'client','/tests/test-all.sh'],check=False)
        save('suite-existente.txt',suite.stdout+suite.stderr)
        if suite.returncode: raise RuntimeError('Suite existente falló: '+clean(suite.stdout+suite.stderr)[-1500:])
        p=execute('client','python3','/tests/test-official.py','--credentials','/tmp/lab5-credentials.json',check=False)
        save('matriz-protocolos.txt',p.stdout+p.stderr)
        rows=json.loads(execute('client','cat','/tmp/official-results.json').stdout)
        def add(test,passed,observed,procedure):
            row=next(r for r in rows if r['id']==test)
            expected={'WEB-05':'Login válido falla al caer LDAP; log del servidor; recuperación verificada',
                      'INT-02':'Regresión PASS; IP/MAC estables; archivos previos conservados',
                      'INT-03':'DNS 53 TCP/UDP; LDAP 389; Web 80; SMTP 25/587; IMAP 143; FTP 21',
                      'INT-04':'Logs de operaciones LDAP, HTTP, autenticación IMAP, entrega SMTP/LMTP y transferencia FTP'}[test]
            row.update(status='PASS' if passed else 'FAIL',expected=expected,observed=clean(observed),procedure=procedure,time=dt.datetime.now(dt.timezone.utc).isoformat())
        # Fallo controlado: no cache LDAP de Apache; sin sesión previa.
        print('WEB-05: caída LDAP y recuperación',flush=True)
        since=dt.datetime.now(dt.timezone.utc).isoformat()
        run([*COMPOSE,'stop','ldap'])
        try:
            payload=urllib.parse.urlencode({'httpd_username':'nmolina','httpd_password':credentials['passwords']['nmolina']})
            code=execute('client','curl','--max-time','20','-s','-o','/dev/null','-w','%{http_code}',
                         '--data-binary','@-','http://www.aerolinea.redes.test/dologin',input=payload,check=False)
            logs=execute('web','tail','-n','40','/var/log/apache2/aerolinea-error.log').stdout
            save('WEB-05.txt','HTTP '+code.stdout+'\n'+logs)
            add('WEB-05',code.returncode==0 and code.stdout in ['500','503'] and bool(re.search(r'(Can.t contact LDAP|server down)',logs,re.I)), 'HTTP '+code.stdout+'; '+logs,'docker compose stop ldap; POST /dologin con credenciales válidas sin cookie; tail log Apache; start ldap en finally')
        finally:
            run([*COMPOSE,'start','ldap'])
            run([*COMPOSE,'up','-d','--wait','--wait-timeout','120'])
        # Registrar IP/MAC reales, reiniciar servicios, repetir toda la matriz.
        def interfaces(service):
            data=json.loads(run(['docker','inspect',run([*COMPOSE,'ps','-q',service]).stdout.strip()]).stdout)[0]['NetworkSettings']['Networks']
            return {name:{key:net[key] for key in ['IPAddress','MacAddress','Gateway','IPPrefixLen']} for name,net in data.items()}
        before={s:interfaces(s) for s in ['dns','ldap','web','mail','ftp','client']}
        save('interfaces-antes-reinicio.json',json.dumps(before,indent=2))
        print('INT-02: reinicio y regresión',flush=True)
        files_before={s:execute(s,'find',path,'-type','f').stdout.splitlines() for s,path in [('mail','/var/mail/vhosts'),('ftp','/srv/ftp')]}
        run([*COMPOSE,'restart','dns','ldap','web','mail','ftp'],timeout=180)
        run([*COMPOSE,'up','-d','--wait','--wait-timeout','120'])
        p=execute('client','python3','/tests/test-official.py','--credentials','/tmp/lab5-credentials.json',check=False)
        save('despues-reinicio.txt',p.stdout+p.stderr)
        after={s:interfaces(s) for s in before}
        save('interfaces-contenedores.json',json.dumps(after,indent=2))
        # Verificar que también persisten mensajes y carga anteriores, sin limitarse a crear nuevos.
        mail_files=execute('mail','find','/var/mail/vhosts','-type','f').stdout
        ftp_files=execute('ftp','find','/srv/ftp','-type','f').stdout
        save('persistencia.txt',mail_files+'\n'+ftp_files)
        files_persist=all(set(files_before[s]) <= set(text.splitlines()) for s,text in [('mail',mail_files),('ftp',ftp_files)])
        add('INT-02',p.returncode==0 and before==after and files_persist,p.stdout+'\nInterfaces estables: '+str(before==after)+'; archivos anteriores conservados: '+str(files_persist),'compose restart cinco servicios; suite completa; comparar interfaces y archivos Maildir/FTP anteriores')
        port_logs=[]; ports_ok=True
        for service,ports in {'dns':[53],'ldap':[389],'web':[80],'mail':[25,143,587],'ftp':[21]}.items():
            cid=run([*COMPOSE,'ps','-q',service]).stdout.strip()
            p=run(['docker','run','--rm','--network','container:'+cid,'--pid','container:'+cid,'lab05-entrega-client','ss','-lntup'])
            port_logs.append(service+'\n'+p.stdout)
            ports_ok &= all(re.search(':'+str(port)+r'\b',p.stdout) is not None for port in ports)
        save('INT-03.txt','\n'.join(port_logs))
        add('INT-03',ports_ok,'\n'.join(port_logs),'ss -lntup desde contenedor auxiliar que comparte network y pid de cada servidor')
        logs=[]
        for service in ['dns','ldap','mail','web','ftp']:
            p=run([*COMPOSE,'logs','--no-color','--since',since,service])
            text=p.stdout+p.stderr
            if service=='web': text+=execute('web','tail','-n','80','/var/log/apache2/aerolinea-error.log','/var/log/apache2/aerolinea-access.log').stdout
            if service=='ftp': text+=execute('ftp','cat','/var/log/vsftpd.log').stdout
            if service=='mail': text+=execute('mail','tail','-n','100','/var/log/postfix.log').stdout
            save('logs-'+service+'.txt',text); logs.append(text)
        combined='\n'.join(logs)
        add('INT-04',all(x in combined for x in ['status=sent','imap-login','slapd','OK UPLOAD','OK DOWNLOAD']), 'Logs por servicio; revisar logs-*.txt. Fallos de autenticación y LDAP esperados durante pruebas negativas.','compose logs y tail logs Apache/vsftpd')
        save('matriz-final.json',json.dumps(rows,ensure_ascii=False,indent=2))
        print('Resultado:',{s:sum(r['status']==s for r in rows) for s in ['PASS','FAIL','BLOCKED']},flush=True)
        if any(r['status']=='FAIL' for r in rows): raise RuntimeError('Hay casos FAIL; ver matriz-final.json')
    finally:
        execute('client','rm','-f','/tmp/lab5-credentials.json')

if __name__=='__main__': main()
