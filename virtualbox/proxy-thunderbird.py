#!/usr/bin/env python3
"""SOCKS5 en loopback Windows por SSH, con resolución FQDN dentro de Ubuntu.
Permite usar Thunderbird sin alterar la configuración DNS de Windows.
Solo admite servidores del dominio del laboratorio.
"""
import importlib.util,socket,socketserver,struct,threading
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
spec=importlib.util.spec_from_file_location('ssh_run',ROOT/'virtualbox/ssh-run.py')
ssh=importlib.util.module_from_spec(spec); spec.loader.exec_module(ssh)
def read(s,n):
    data=b''
    while len(data)<n:
        b=s.recv(n-len(data))
        if not b: raise EOFError()
        data+=b
    return data
class Handler(socketserver.BaseRequestHandler):
    def handle(self):
        s=self.request; channel=None
        try:
            version,count=read(s,2); methods=read(s,count)
            if version!=5 or 0 not in methods: return
            s.sendall(b'\x05\x00')
            version,cmd,_,kind=read(s,4)
            if cmd!=1 or kind!=3: raise ValueError('Solo CONNECT con DNS remoto')
            hostname=read(s,read(s,1)[0]).decode('ascii'); port=struct.unpack('!H',read(s,2))[0]
            allowed={'mail.aerolinea.redes.test':(143,587),'www.aerolinea.redes.test':(80,)}
            if port not in allowed.get(hostname,()): raise ValueError('Fuera del laboratorio')
            with self.server.lock:
                transport=self.server.ssh.get_transport()
                if transport is None or not transport.is_active():
                    self.server.ssh.close();self.server.ssh=ssh.connect()
                    self.server.ssh.get_transport().set_keepalive(30)
                channel=self.server.ssh.get_transport().open_channel('direct-tcpip',(hostname,port),self.client_address,timeout=30)
            s.sendall(b'\x05\x00\x00\x01\x00\x00\x00\x00\x00\x00')
            def pump(source,dest):
                try:
                    while data:=source.recv(65536): dest.sendall(data)
                except (OSError,EOFError): pass
                finally:
                    try: dest.shutdown(socket.SHUT_WR)
                    except (OSError,TypeError): pass
            t=threading.Thread(target=pump,args=(s,channel),daemon=True); t.start()
            pump(channel,s); t.join(timeout=3)
        except Exception:
            try: s.sendall(b'\x05\x01\x00\x01\x00\x00\x00\x00\x00\x00')
            except OSError: pass
        finally:
            if channel: channel.close()
class Server(socketserver.ThreadingTCPServer):
    allow_reuse_address=True
    daemon_threads=True
if __name__=='__main__':
    with Server(('127.0.0.1',10805),Handler) as server:
        server.ssh=ssh.connect(); server.ssh.get_transport().set_keepalive(30)
        server.lock=threading.Lock()
        try: server.serve_forever()
        finally: server.ssh.close()
