#!/usr/bin/env python3
"""Pruebas de protocolos: matriz oficial con alcance explícito y sin secretos en logs.

Ejecutar en un cliente Linux separado: python3 test-official.py --credentials /ruta/privada.json
El JSON contiene passwords (uid -> clave) y ftp_user/ftp_password. No se guarda en Git.
INT-02/03/04 y WEB-05 los registra el orquestador; Thunderbird requiere evidencia gráfica.
"""
import argparse
import datetime as dt
import ftplib
import hashlib
import http.cookiejar
import imaplib
import io
import inspect
import json
import os
from pathlib import Path
import re
import smtplib
import socket
import subprocess
import tempfile
import time
import urllib.parse
import urllib.request

USERS = {'fruiz': ('Fernando Ruiz','Ruiz'), 'hbarillas': ('Hugo Barillas','Barillas'),
         'icumes': ('Ian Cumes','Cumes'), 'jvalladares': ('Javier Valladares','Valladares'),
         'nmolina': ('Nery Molina','Molina'), 'mpolanco': ('Milton Polanco','Polanco')}
DOMAIN = 'aerolinea.redes.test'
BASE = 'dc=aerolinea,dc=redes,dc=test'
socket.setdefaulttimeout(15)

def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--credentials', type=Path, required=True)
    ap.add_argument('--output', type=Path, default=Path('/tmp/official-results.json'))
    ap.add_argument('--scope', default='Docker; cliente separado, mismo host físico')
    args = ap.parse_args()
    credentials = json.loads(args.credentials.read_text())
    passwords = credentials['passwords']
    rows = []
    def record(test, function, expected):
        now = dt.datetime.now(dt.timezone.utc).isoformat()
        try:
            observed = function()
            status = 'PASS'
        except Exception as exc:
            status, observed = 'FAIL', f'{type(exc).__name__}: {exc}'
        text = str(observed)
        for secret in [*passwords.values(), credentials['ftp_password']]:
            text = text.replace(secret, '[REDACTED]')
        row = dict(id=test,status=status,expected=expected,observed=text,time=now,
                   machine=socket.gethostname(),scope=args.scope,procedure=function.__doc__ or inspect.getsource(function).strip())
        rows.append(row)
        print(f'[{status}] {test}: {text}', flush=True)
    def blocked(test, reason):
        rows.append(dict(id=test,status='BLOCKED',expected=reason,observed=reason,
                         time=dt.datetime.now(dt.timezone.utc).isoformat(),machine=socket.gethostname(),scope=args.scope,procedure='Pendiente'))
    def run(*cmd):
        p = subprocess.run(cmd,capture_output=True,text=True,timeout=20)
        assert p.returncode == 0, p.stderr
        return p.stdout
    def dns(name, typ='A', expected=None):
        answer = run('dig','+time=3','+tries=1','+short',name,typ).strip()
        assert answer and (expected is None or answer == expected), answer
        return answer
    record('DNS-01',lambda: dns('ns1.'+DOMAIN,expected=os.getenv('DNS_SERVER')), 'IP de ns1 correcta')
    def services():
        """dig +short ldap/www/mail/ftp.aerolinea.redes.test A; comparar con zona esperada"""
        zone = Path(os.getenv('ZONE_FILE','/zones/db.'+DOMAIN)).read_text()
        return {role:dns(role+'.'+DOMAIN,expected=re.search(r'^'+role+r'\s+IN\s+A\s+(\S+)',zone,re.M)[1]) for role in ('ldap','www','mail','ftp')}
    record('DNS-02',services,'Cuatro IP coinciden con la zona')
    def soa():
        """dig +norecurse @DNS_SERVER aerolinea.redes.test SOA"""
        answer=run('dig','+norecurse','+time=3','+tries=1','@'+os.environ['DNS_SERVER'],DOMAIN,'SOA')
        assert re.search(r'flags:[^;]*\baa\b',answer), answer
        return answer
    record('DNS-03',soa,'SOA con flag aa')
    record('DNS-04',lambda:dns(DOMAIN,'MX','10 mail.'+DOMAIN+'.'),'MX prioridad 10')
    def nx():
        """dig noexiste.aerolinea.redes.test A"""
        answer=run('dig','+time=3','+tries=1','noexiste.'+DOMAIN,'A')
        assert 'status: NXDOMAIN' in answer,answer
        return answer
    record('DNS-05',nx,'NXDOMAIN')
    ldap=['-x','-o','nettimeout=5','-H','ldap://ldap.'+DOMAIN+':'+os.getenv('LDAP_PORT','389')]
    def query():
        return run('ldapsearch',*ldap,'-LLL','-b','ou=People,'+BASE,'(objectClass=inetOrgPerson)','uid','cn','sn','mail')
    def users():
        """ldapsearch -LLL -b ou=People,... uid cn sn mail; exigir las seis cuentas"""
        answer=query()
        assert set(USERS) <= set(re.findall(r'^uid: (.*)$',answer,re.M)),answer
        return answer
    record('LDAP-01',users,'Seis integrantes presentes; pueden existir fixtures adicionales')
    def bind(uid,password):
        with tempfile.NamedTemporaryFile(mode='w') as f:
            os.chmod(f.name,0o600); f.write(password); f.flush()
            return subprocess.run(['ldapwhoami',*ldap,'-D','uid='+uid+',ou=People,'+BASE,'-y',f.name],capture_output=True,text=True,timeout=15)
    def valid():
        """ldapwhoami con archivo privado -y; bind individual de seis uid"""
        for uid,password in passwords.items():
            p=bind(uid,password); assert p.returncode==0 and ('dn:uid='+uid+',') in p.stdout,uid+': '+p.stderr
        return 'Seis binds válidos'
    record('LDAP-02',valid,'Bind correcto de los seis')
    def invalid():
        """ldapwhoami de cada uid con clave incorrecta y de usuario inexistente; exigir LDAP 49"""
        for uid in [*USERS,'noexiste']:
            p=bind(uid,'incorrecta-audit'); assert p.returncode==49 and 'Invalid credentials (49)' in p.stderr,uid+': '+p.stderr
        return 'Siete rechazos LDAP 49'
    record('LDAP-03',invalid,'Credenciales rechazadas con LDAP 49')
    def attributes():
        """ldapsearch uid cn sn mail; comparar identidad y correo de cada integrante"""
        answer=query()
        for uid,(cn,sn) in USERS.items():
            block=next(b for b in answer.split('\n\n') if '\nuid: '+uid+'\n' in '\n'+b+'\n')
            for line in ['cn: '+cn,'sn: '+sn,'mail: '+uid+'@'+DOMAIN]:
                assert line in block,uid+': falta '+line
        return answer
    record('LDAP-04',attributes,'Identidades y correos correctos en seis cuentas')
    url='http://www.'+DOMAIN
    def browser():
        return urllib.request.build_opener(urllib.request.HTTPCookieProcessor(http.cookiejar.CookieJar()))
    def login(opener,uid,password):
        data=urllib.parse.urlencode({'httpd_username':uid,'httpd_password':password}).encode()
        return opener.open(url+'/dologin',data,timeout=15)
    record('WEB-01',lambda:dns('www.'+DOMAIN),'DNS del sitio')
    def home():
        """HTTP GET / por FQDN; exigir marca del sitio React/Vite"""
        r=browser().open(url,timeout=15)
        assert r.status==200 and 'Aerolínea Redes' in r.read().decode(),r.status
        return 'HTTP 200; Aerolínea Redes'
    record('WEB-02',home,'Página original accesible; evidencia HTTP, captura gráfica pendiente')
    def webvalid():
        """HTTP POST /dologin y GET /privado/usuario.json para las seis cuentas"""
        for uid,password in passwords.items():
            b=browser(); r=login(b,uid,password); assert '/privado/' in r.url,uid+': '+r.url
            identity=json.loads(b.open(url+'/privado/usuario.json').read()); assert identity['uid']==uid,identity
            b.open(url+'/logout').read(); assert '/login/' in b.open(url+'/privado/').url,'Logout falló'
        return 'Seis logins y logout correctos'
    record('WEB-03',webvalid,'Área privada accesible solo con sesión válida')
    def webinvalid():
        """POST /dologin con clave incorrecta y usuario inexistente; exigir redirección a login"""
        for uid in ['nmolina','noexiste']:
            b=browser(); r=login(b,uid,'incorrecta-audit'); assert '/login/' in r.url,r.url
            assert '/login/' in b.open(url+'/privado/').url,'Área privada accesible'
        return 'Ambos accesos rechazados'
    record('WEB-04',webinvalid,'No se crea sesión autorizada')
    blocked('WEB-05','El orquestador detiene LDAP y verifica recuperación y log')
    record('MAIL-01',lambda:(dns('mail.'+DOMAIN),dns(DOMAIN,'MX','10 mail.'+DOMAIN+'.')),'A y MX correctos')
    for test in ['MAIL-02','MAIL-03','MAIL-06']:
        blocked(test,'El PDF oficial exige Thunderbird; las pruebas de protocolo se guardan como evidencia complementaria')
    def imap(uid,password):
        c=imaplib.IMAP4('mail.'+DOMAIN,143); c.login(uid,password); return c
    def mailinvalid():
        """IMAP LOGIN con clave incorrecta; exigir respuesta NO, no error de conectividad"""
        c=imaplib.IMAP4('mail.'+DOMAIN,143)
        try:
            try: c.login('nmolina','incorrecta-audit')
            except imaplib.IMAP4.error as exc:
                assert 'AUTHENTICATIONFAILED' in str(exc),str(exc)
                return 'IMAP AUTHENTICATIONFAILED; reproducción gráfica pendiente'
            raise AssertionError('Autenticación incorrecta aceptada')
        finally: c.logout()
    record('MAIL-04',mailinvalid,'Dovecot rechaza credenciales incorrectas')
    subject='Lab5-audit-'+str(time.time_ns())
    body='Contenido verificable '+subject
    def send():
        """SMTP AUTH LOGIN/PLAIN :587 nmolina -> jvalladares; mensaje único; IMAP FETCH contenido"""
        with smtplib.SMTP('mail.'+DOMAIN,587,timeout=15) as s:
            s.login('nmolina',passwords['nmolina'])
            refused=s.sendmail('nmolina@'+DOMAIN,['jvalladares@'+DOMAIN],f'Subject: {subject}\r\nFrom: nmolina@{DOMAIN}\r\nTo: jvalladares@{DOMAIN}\r\n\r\n{body}\r\n')
            assert not refused,refused
        for _ in range(15):
            c=imap('jvalladares',passwords['jvalladares'])
            try:
                c.select('INBOX'); status,data=c.uid('search',None,'SUBJECT',subject)
                if data[0]:
                    status,msg=c.uid('fetch',data[0].split()[-1],'(RFC822)')
                    payloads=[item[1] for item in msg if isinstance(item,tuple) and isinstance(item[1],bytes)]
                    assert status=='OK' and any(body.encode() in payload for payload in payloads),msg
                    return 'SMTP entregado e IMAP FETCH verificado: '+subject
            finally: c.logout()
            time.sleep(1)
        raise AssertionError('Mensaje único no recibido')
    record('MAIL-05',send,'Envío entre dos integrantes y entrega real; IMAP complementario')
    def recipient():
        """SMTP autenticado, RCPT TO noexiste; exigir rechazo 550"""
        with smtplib.SMTP('mail.'+DOMAIN,587,timeout=15) as s:
            s.login('nmolina',passwords['nmolina']); s.mail('nmolina@'+DOMAIN)
            code,message=s.rcpt('noexiste@'+DOMAIN); assert code==550,(code,message)
            return str(code)+' '+message.decode()
    record('MAIL-07',recipient,'550 destinatario inexistente')
    def ftp(user=None,password=None):
        f=ftplib.FTP('ftp.'+DOMAIN,timeout=15)
        try: f.login(user or credentials['ftp_user'],password or credentials['ftp_password'])
        except Exception:
            f.close(); raise
        return f
    record('FTP-01',lambda:dns('ftp.'+DOMAIN),'DNS FTP')
    def ftpvalid():
        """FTP USER/PASS y QUIT por FQDN"""
        f=ftp(); answer=f.getwelcome(); f.quit(); return answer
    record('FTP-02',ftpvalid,'Login válido')
    def ftpreject(user,password):
        try: f=ftp(user,password)
        except ftplib.error_perm as exc:
            assert str(exc).startswith('530'),str(exc)
            return str(exc)
        f.quit(); raise AssertionError('Login indebido aceptado')
    record('FTP-03',lambda:ftpreject(credentials['ftp_user'],'incorrecta-audit'),'530 clave incorrecta')
    record('FTP-04',lambda:ftpreject('anonymous','audit@example.test'),'530 anónimo')
    def listing():
        """FTP NLST pasivo; exigir bienvenida.txt"""
        f=ftp()
        try:
            names=f.nlst(); assert 'bienvenida.txt' in names,names; return names
        finally: f.quit()
    record('FTP-05',listing,'Listado autorizado')
    payload=('Prueba FTP '+subject).encode(); filename='uploads/'+subject+'.txt'
    def upload():
        """FTP STOR uploads/<id único>.txt en modo pasivo"""
        f=ftp()
        try: return f.storbinary('STOR '+filename,io.BytesIO(payload))
        finally: f.quit()
    record('FTP-06',upload,'226 carga completa')
    def download():
        """FTP RETR del mismo archivo; comparar bytes y SHA256"""
        f=ftp(); data=io.BytesIO()
        try: f.retrbinary('RETR '+filename,data.write)
        finally: f.quit()
        assert data.getvalue()==payload,'Contenido distinto'
        return 'SHA256 '+hashlib.sha256(payload).hexdigest()
    record('FTP-07',download,'Descarga idéntica')
    def chroot():
        """FTP CWD .. debe permanecer en /; RETR /etc/passwd debe dar 550"""
        f=ftp()
        try:
            f.cwd('/'); f.cwd('..'); assert f.pwd()=='/',f.pwd()
            try: f.retrbinary('RETR /etc/passwd',lambda _:None)
            except ftplib.error_perm as exc:
                assert str(exc).startswith('550'),str(exc); return 'CWD .. permanece /; '+str(exc)
            raise AssertionError('Archivo del host expuesto')
        finally: f.quit()
    record('FTP-08',chroot,'No se escapa de chroot')
    def names():
        """Inspeccionar /etc/hosts y exigir pruebas FQDN de todos los protocolos PASS"""
        hosts=Path('/etc/hosts').read_text(); assert DOMAIN not in hosts,hosts
        required=['LDAP-02','WEB-03','MAIL-05','FTP-02']
        assert all(next(r for r in rows if r['id']==i)['status']=='PASS' for i in required)
        return hosts+'\nTodos los protocolos usan FQDN'
    record('INT-01',names,'Sin sustitución de DNS en /etc/hosts')
    for test in ['INT-02','INT-03','INT-04']: blocked(test,'Evidencia de servidores registrada por el orquestador')
    args.output.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    assert len(rows)==33
    return 1 if any(r['status']=='FAIL' for r in rows) else 0

if __name__=='__main__': raise SystemExit(main())
