#!/usr/bin/env python3
"""Ejecuta Shell por SSH en Ubuntu VirtualBox; fija host key tras primer acceso NAT verificado."""
import argparse,sys,time
from pathlib import Path
import paramiko
sys.stdout.reconfigure(encoding='utf8',errors='replace')
sys.stderr.reconfigure(encoding='utf8',errors='replace')
ROOT=Path(__file__).resolve().parent.parent
PRIVATE=ROOT/'.git/virtualbox-private'
def connect(host='192.168.56.10',port=22):
    c=paramiko.SSHClient()
    known=PRIVATE/'known_hosts'
    if known.exists(): c.load_host_keys(str(known))
    c.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    c.connect(host,port=port,username='labadmin',key_filename=str(PRIVATE/'id_rsa'),timeout=30,banner_timeout=60,auth_timeout=60,allow_agent=False,look_for_keys=False)
    c.save_host_keys(str(known))
    return c
def main():
    ap=argparse.ArgumentParser()
    ap.add_argument('--host',default='192.168.56.10'); ap.add_argument('--port',type=int,default=22)
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
