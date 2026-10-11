#!/usr/bin/env python3
"""Caída LDAP, puertos/logs y reinicio REAL de Ubuntu VirtualBox por SSH.
Completa la matriz Windows con evidencias propias y resultados Thunderbird.
"""
import datetime,importlib.util,json,re,socket,time,urllib.parse,urllib.request,subprocess,sys
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
E=ROOT/'docs/evidencias/virtualbox'
def module(name,file):
    spec=importlib.util.spec_from_file_location(name,ROOT/'virtualbox'/file)
    m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m
ssh=module('ssh_run','ssh-run.py')
windows=module('windows_tests','pruebas-windows.py')
def remote(command):
    c=ssh.connect()
    try:
        _,o,e=c.exec_command(command,timeout=240)
        output=o.read().decode('utf8',errors='replace')+e.read().decode('utf8',errors='replace')
        code=o.channel.recv_exit_status()
        if code: raise RuntimeError(f'Comando remoto terminó {code}: {output}')
        return output
    finally:c.close()
def main():
    E.mkdir(parents=True,exist_ok=True)
    rows=json.loads((E/'resultados-windows.json').read_text(encoding='utf8'))
    creds=json.loads((ROOT/'.git/lab5-private/credentials.json').read_text())
    for tb in json.loads((E/'resultados-thunderbird.json').read_text(encoding='utf8')):
        row=next(r for r in rows if r['id']==tb['id']);row.update(tb,procedure='Thunderbird real en Windows, automatizado mediante Marionette; capturas y resultados-thunderbird.json')
    def add(test,fn,expected,procedure):
        try: observed=fn();status='PASS'
        except Exception as exc: observed=f'{type(exc).__name__}: {exc}';status='FAIL'
        row=next(r for r in rows if r['id']==test)
        row.update(status=status,expected=expected,observed=observed,procedure=procedure,time=datetime.datetime.now(datetime.timezone.utc).isoformat(),machine=socket.gethostname(),scope='Windows independiente y Ubuntu nativo en VirtualBox, mismo equipo físico')
        (E/'matriz-final.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False),encoding='utf8')
        print(test,status,str(observed)[:350],flush=True)
    def outage():
        remote('sudo systemctl stop slapd')
        try:
            payload=urllib.parse.urlencode({'httpd_username':'nmolina','httpd_password':creds['passwords']['nmolina']}).encode()
            opener=urllib.request.build_opener(urllib.request.ProxyHandler({}))
            try: response=opener.open('http://www.aerolinea.redes.test/dologin',payload,timeout=25);code=response.status
            except urllib.error.HTTPError as exc:code=exc.code
            logs=remote('sudo tail -n 35 /var/log/apache2/aerolinea-error.log')
            assert code in (500,503),code
            assert re.search(r"Can't contact LDAP|server down",logs,re.I),logs
            (E/'WEB-05.txt').write_text(f'HTTP desde Windows: {code}\n'+logs,encoding='utf8')
        finally:remote('sudo systemctl start slapd')
        for attempt in range(10):
            b=urllib.request.build_opener(urllib.request.ProxyHandler({}),urllib.request.HTTPCookieProcessor())
            try:
                r=b.open('http://www.aerolinea.redes.test/dologin',payload,timeout=25)
                if '/privado/' in r.url:break
            except urllib.error.HTTPError as exc:
                if exc.code not in (500,503):raise
            time.sleep(2)
        else:raise AssertionError('Login LDAP no se recuperó en diez intentos')
        return f'HTTP {code} durante caída LDAP; login recuperado tras systemctl start; ver WEB-05.txt'
    add('WEB-05',outage,'Falla controlada y recuperación LDAP','systemctl stop slapd; POST sin sesión desde Windows; leer log Apache; restaurar slapd en finally; login válido')
    def reboot():
        boot_before=remote('cat /proc/sys/kernel/random/boot_id').strip()
        inventory="ip -j addr; sudo find /var/mail/vhosts -type f \\( -path '*/Maildir/cur/*' -o -path '*/Maildir/new/*' \\) -exec sha256sum {} +; sudo find /srv/ftp -type f -exec sha256sum {} +"
        before=remote(inventory);(E/'antes-reinicio.txt').write_text(boot_before+'\n'+before,encoding='utf8')
        c=ssh.connect()
        try:
            _,out,err=c.exec_command('sudo systemctl reboot --no-block',timeout=10)
            out.channel.recv_exit_status()
        finally:c.close()
        time.sleep(10)
        deadline=time.monotonic()+600
        while time.monotonic()<deadline:
            try:
                boot_after=remote('cat /proc/sys/kernel/random/boot_id; systemctl is-active named slapd apache2 postfix@- dovecot vsftpd').strip()
                lines=boot_after.splitlines()
                if lines[0]!=boot_before and lines[1:]==['active']*6:break
            except Exception:pass
            time.sleep(10)
        else:raise AssertionError('VM no recuperó seis servicios tras reinicio')
        after=remote(inventory);(E/'despues-reinicio.txt').write_text(boot_after+'\n'+after,encoding='utf8')
        before_lines=before.splitlines();after_lines=after.splitlines()
        b=json.loads(before_lines[0]);a=json.loads(after_lines[0])
        def interfaces(data):return {v['ifname']:(v.get('address'),[(x['local'],x['prefixlen']) for x in v.get('addr_info',[]) if x['family']=='inet']) for v in data}
        assert interfaces(b)==interfaces(a),'IP/MAC cambió'
        hashes=lambda lines:set(re.findall(r'^[a-f0-9]{64}', '\n'.join(lines),re.M))
        assert hashes(before_lines) and hashes(before_lines)<=hashes(after_lines),'Archivos anteriores ausentes'
        subprocess.run([sys.executable,str(ROOT/'virtualbox/pruebas-windows.py')],check=True)
        regression=(E/'resultados-windows.json').read_text(encoding='utf8')
        (E/'resultados-windows-despues-reinicio.json').write_text(regression,encoding='utf8')
        checks=json.loads(regression)
        assert sum(r['status']=='PASS' for r in checks)==26 and not any(r['status']=='FAIL' for r in checks),'Regresión después del reinicio'
        return 'Boot ID distinto; seis servicios activos; IP/MAC conservadas; contenido Maildir/FTP conserva SHA256. Ver antes/despues-reinicio.txt'
    add('INT-02',reboot,'Reinicio real y persistencia de servicios/datos','systemctl reboot de la VM; esperar SSH y seis unidades; comparar boot ID, interfaces y SHA256')
    def ports():
        out=remote('sudo ss -lntup; systemctl is-enabled named slapd apache2 postfix dovecot vsftpd; systemd-detect-virt; sudo systemctl show named slapd apache2 postfix@- dovecot vsftpd -p MainPID -p ControlGroup')
        (E/'INT-03.txt').write_text(out,encoding='utf8')
        assert all(re.search(':'+str(p)+r'\b',out) for p in [53,389,80,25,587,143,21]),out
        assert re.search(r'udp.*:53\b',out),out
        assert 'oracle' in out and '/system.slice/' in out,out
        return '53 TCP/UDP, 389,80,25,587,143,21; procesos nativos /system.slice, VirtualBox oracle. Ver INT-03.txt'
    add('INT-03',ports,'Puertos activos y unidades nativas habilitadas','ss -lntup; systemctl is-enabled/show; systemd-detect-virt')
    def logs():
        out=remote('sudo journalctl --since today --no-pager -n 1200; sudo tail -n 100 /var/log/apache2/aerolinea-access.log /var/log/apache2/aerolinea-error.log /var/log/vsftpd.log')
        for secret in [*creds['passwords'].values(),creds['ftp_password'],creds['admin_password']]:out=out.replace(secret,'[REDACTED]')
        (E/'logs-nativos.txt').write_text(out,encoding='utf8')
        assert all(s in out for s in ['status=sent','imap-login','slapd','OK UPLOAD','OK DOWNLOAD']), 'Faltan registros completos; revisar logs-nativos.txt'
        return 'Logs de bind LDAP, HTTP, SMTP/LMTP, IMAP, carga y descarga FTP; ver logs-nativos.txt'
    add('INT-04',logs,'Registros reales de operaciones','journalctl nativo y archivos Apache/vsftpd; redacción de secretos antes de guardar')
    (E/'matriz-final.json').write_text(json.dumps(rows,indent=2,ensure_ascii=False),encoding='utf8')
    print({s:sum(r['status']==s for r in rows) for s in ['PASS','FAIL','BLOCKED']})
    return int(any(r['status']=='FAIL' for r in rows))
if __name__=='__main__':raise SystemExit(main())
