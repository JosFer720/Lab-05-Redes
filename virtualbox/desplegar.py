#!/usr/bin/env python3
"""Transfiere el laboratorio y secretos por SFTP y ejecuta instalación nativa.
Requiere SSH operativo, credenciales renovadas .git/lab5-private/credentials.json.
"""
import importlib.util,json,re,shlex,subprocess,tarfile
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('ssh_run',ROOT/'virtualbox/ssh-run.py')
ssh=importlib.util.module_from_spec(spec); spec.loader.exec_module(ssh)
def main():
    private=ROOT/'.git/virtualbox-private'
    credentials=json.loads((ROOT/'.git/lab5-private/credentials.json').read_text())
    ldif=(ROOT/'ldap/ldif/usuarios-laboratorio.ldif').read_text(encoding='utf8')
    tsv=[]
    for block in ldif.split('\n\n'):
        attrs=dict(re.findall(r'^(uid|cn|sn|mail): (.+)$',block,re.M))
        if 'uid' in attrs:
            tsv.append('\t'.join([attrs[k] for k in ['uid','cn','sn','mail']]+[credentials['passwords'][attrs['uid']]]))
    (private/'users.tsv').write_text('\n'.join(tsv)+'\n',encoding='utf8',newline='\n')
    env={'LDAP_ADMIN_PASSWORD':credentials['admin_password'],'USERS_FILE':'/root/lab5-private/users.tsv',
         'FTP_USER':credentials['ftp_user'],'FTP_PASSWORD':credentials['ftp_password']}
    (private/'deploy.env').write_text(''.join('export '+k+'='+shlex.quote(v)+'\n' for k,v in env.items()),newline='\n')
    archive=private/'source.tar.gz'
    with tarfile.open(archive,'w:gz') as tar:
        for directory in ['dns','ldap','web','mail','ftp','client','virtualbox']:
            for f in (ROOT/directory).rglob('*'):
                if f.is_file() and not any(part in ['node_modules','__pycache__','dist','.venv'] for part in f.relative_to(ROOT).parts):
                    tar.add(f,arcname=f.relative_to(ROOT).as_posix())
    c=ssh.connect()
    def command(cmd):
        _,out,err=c.exec_command(cmd,timeout=1800)
        for line in out: print(line,end='',flush=True)
        error=err.read().decode(); print(error,end='')
        if out.channel.recv_exit_status(): raise RuntimeError('Comando remoto falló; revise salida')
    try:
        command('mkdir -p /home/labadmin/lab5-upload; sudo install -d -m 0700 /root/lab5-private /opt/lab5')
        with c.open_sftp() as s:
            for local,name in [(archive,'source.tar.gz'),(private/'users.tsv','users.tsv'),(private/'deploy.env','deploy.env'),(ROOT/'.git/lab5-private/credentials.json','credentials.json')]:
                remote='/home/labadmin/lab5-upload/'+name; s.put(str(local),remote); s.chmod(remote,0o600)
        command('sudo tar -xzf /home/labadmin/lab5-upload/source.tar.gz -C /opt/lab5; sudo install -m 0600 /home/labadmin/lab5-upload/users.tsv /home/labadmin/lab5-upload/deploy.env /home/labadmin/lab5-upload/credentials.json /root/lab5-private/; rm /home/labadmin/lab5-upload/users.tsv /home/labadmin/lab5-upload/deploy.env /home/labadmin/lab5-upload/credentials.json; sudo bash /opt/lab5/virtualbox/instalar-servicios.sh')
    finally: c.close()
if __name__=='__main__': main()
