#!/usr/bin/env python3
"""Cliente Windows independiente: consulta BIND por DNS real, sin alterar DNS/hosts.
Adaptador CLI dig/ldapsearch/ldapwhoami para la matriz compartida.
Requiere pip install dnspython ldap3; la resolución solo afecta este proceso.
"""
import argparse,importlib.util,os,re,socket,subprocess,sys,tempfile,urllib.request
from pathlib import Path
sys.stdout.reconfigure(encoding='utf8',errors='replace')
import dns.flags,dns.message,dns.query,dns.rcode,dns.resolver
import ldap3
ROOT=Path(__file__).resolve().parent.parent
SERVER='192.168.56.10'
original_addr=socket.getaddrinfo
resolver=dns.resolver.Resolver(configure=False); resolver.nameservers=[SERVER]; resolver.timeout=3; resolver.lifetime=5
def address(host,*args,**kwargs):
    if isinstance(host,str) and host.endswith('.aerolinea.redes.test'):
        host=str(resolver.resolve(host,'A')[0])
    return original_addr(host,*args,**kwargs)
socket.getaddrinfo=address
original_run=subprocess.run
def run(cmd,**kwargs):
    if cmd[0]=='dig':
        words=[s for s in cmd[1:] if not s.startswith(('+','@'))]
        name,typ=words[0],words[1] if len(words)>1 else 'A'
        q=dns.message.make_query(name,typ)
        if '+norecurse' in cmd: q.flags &= ~dns.flags.RD
        a=dns.query.udp(q,SERVER,timeout=4)
        text='\n'.join(r.to_text() for rr in a.answer for r in rr)
        if '+short' not in cmd:
            text='status: '+dns.rcode.to_text(a.rcode())+'; flags: '+dns.flags.to_text(a.flags).lower()+';\n'+a.to_text()
        return subprocess.CompletedProcess(cmd,0,text,'')
    if cmd[0] in ['ldapsearch','ldapwhoami']:
        def opt(flag,default=None): return cmd[cmd.index(flag)+1] if flag in cmd else default
        uri=opt('-H'); hostname=uri.split('://')[1].split(':')[0]
        server=ldap3.Server(str(resolver.resolve(hostname,'A')[0]),port=389,connect_timeout=5)
        user=opt('-D'); password=Path(opt('-y')).read_text() if '-y' in cmd else None
        c=ldap3.Connection(server,user=user,password=password,authentication=ldap3.SIMPLE if user else ldap3.ANONYMOUS,receive_timeout=10)
        if not c.bind():
            return subprocess.CompletedProcess(cmd,c.result['result'],'','Invalid credentials (49)' if c.result['result']==49 else str(c.result))
        try:
            if cmd[0]=='ldapwhoami': return subprocess.CompletedProcess(cmd,0,'dn:'+user+'\n','')
            c.search(opt('-b'),'(objectClass=inetOrgPerson)',attributes=['uid','cn','sn','mail'])
            text='\n\n'.join('dn: '+e.entry_dn+'\n'+'\n'.join(k+': '+str(e[k].value) for k in ['uid','cn','sn','mail']) for e in c.entries)
            return subprocess.CompletedProcess(cmd,0,text,'')
        finally: c.unbind()
    return original_run(cmd,**kwargs)
class Temp:
    def __enter__(self):
        self.f=tempfile.NamedTemporaryFile(mode='w',delete=False); return self.f
    def __exit__(self,*args):
        self.f.close(); Path(self.f.name).unlink(missing_ok=True)
def main():
    spec=importlib.util.spec_from_file_location('official',ROOT/'client/tests/test-official.py')
    m=importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
    m.subprocess.run=run
    m.tempfile=type('TempAdapter',(),{'NamedTemporaryFile':staticmethod(lambda **kw:Temp())})
    OriginalPath=Path
    m.Path=lambda name:OriginalPath(os.environ['SystemRoot']+'/System32/drivers/etc/hosts' if str(name)=='/etc/hosts' else name)
    # Evitar proxy del host para el dominio del laboratorio.
    os.environ['no_proxy']='.aerolinea.redes.test,192.168.56.10'
    os.environ['DNS_SERVER']=SERVER
    os.environ['ZONE_FILE']=str(ROOT/'virtualbox/zona-efectiva.txt')
    sys.argv=[sys.argv[0],'--credentials',str(ROOT/'.git/lab5-private/credentials.json'),'--output',str(ROOT/'docs/evidencias/virtualbox/resultados-windows.json'),'--scope','Windows independiente -> Ubuntu VirtualBox host-only; DNS real consultado por dnspython']
    code=m.main()
    output=ROOT/'docs/evidencias/virtualbox/resultados-windows.json'
    import json
    rows=json.loads(output.read_text(encoding='utf8'))
    for row in rows:
        prefix=('Windows: dnspython contra BIND real; ' if row['id'].startswith('DNS-') else
                'Windows: ldap3, bind/búsqueda/rechazo LDAP reales; ' if row['id'].startswith('LDAP-') else
                'Windows: protocolos nativos Python y resolución A consultada a BIND; ')
        row['procedure']=prefix+row['procedure']
    output.write_text(json.dumps(rows,ensure_ascii=False,indent=2),encoding='utf8')
    return code
if __name__=='__main__': raise SystemExit(main())
