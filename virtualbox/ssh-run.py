#!/usr/bin/env python3
"""Ejecuta Shell por SSH en Ubuntu VirtualBox; fija host key tras primer acceso NAT verificado."""
import argparse,logging,os,sys,time
from pathlib import Path
import paramiko
# Mientras Ubuntu arranca, el reenvío NAT acepta la conexión antes de que sshd responda y paramiko escribe un
# traceback por cada intento; las esperas ya reintentan, así que se silencia ese ruido (los errores siguen lanzándose).
logging.getLogger('paramiko').setLevel(logging.CRITICAL)
sys.stdout.reconfigure(encoding='utf8',errors='replace')
sys.stderr.reconfigure(encoding='utf8',errors='replace')
ROOT=Path(__file__).resolve().parent.parent
PRIVATE=(Path(os.environ['LAB5_PRIVATE_DIR']) if os.environ.get('LAB5_PRIVATE_DIR') else ROOT/'.git')/'virtualbox-private'
# En modo puente la VM se administra por el reenvío NAT: LAB_SSH_HOST=127.0.0.1 LAB_SSH_PORT=22225.
DEFAULT_HOST=os.environ.get('LAB_SSH_HOST','192.168.56.10')
DEFAULT_PORT=int(os.environ.get('LAB_SSH_PORT','22'))
def connect(host=DEFAULT_HOST,port=DEFAULT_PORT):
    c=paramiko.SSHClient()
    known=PRIVATE/'known_hosts'
    if known.exists(): c.load_host_keys(str(known))
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(host,port=port,username='labadmin',key_filename=str(PRIVATE/'id_rsa'),timeout=30,banner_timeout=60,auth_timeout=60,allow_agent=False,look_for_keys=False)
    c.save_host_keys(str(known))
    return c
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--host',default=DEFAULT_HOST); ap.add_argument('--port',type=int,default=DEFAULT_PORT)
    ap.add_argument('--command',default='hostnamectl; cat /etc/os-release; whoami; ip -br addr; ip route; sudo systemctl status ssh --no-pager')
    args=ap.parse_args()
    c=connect(args.host,args.port)
    try:
        stdin,stdout,stderr=c.exec_command(args.command,timeout=1200)
        if not sys.stdin.isatty():
            data=sys.stdin.buffer.read().replace(b'\r\n',b'\n')
            if data: stdin.write(data); stdin.flush()
        stdin.channel.shutdown_write()
        for line in stdout: print(line,end='',flush=True)
        print(stderr.read().decode('utf8',errors='replace'),end='',file=sys.stderr)
        return stdout.channel.recv_exit_status()
    finally: c.close()
if __name__=='__main__': raise SystemExit(main())
