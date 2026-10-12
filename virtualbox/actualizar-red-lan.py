#!/usr/bin/env python3
"""Ejecutar con sudo en Ubuntu tras obtener DHCP en la interfaz puenteada."""
import ipaddress,json,re,subprocess,time
from pathlib import Path
def run(*args):return subprocess.check_output(args,text=True)
assert __import__('os').geteuid()==0,'Ejecute con sudo'
data=json.loads(run('ip','-j','-4','addr','show','enp0s3'))[0]
addresses=[a for a in data['addr_info'] if a['scope']=='global']
assert len(addresses)==1,'No hay una IPv4 DHCP inequívoca'
addr=addresses[0];ip=addr['local'];network=str(ipaddress.ip_network(f"{ip}/{addr['prefixlen']}",strict=False))
assert ip!='10.0.2.15','La interfaz todavía usa NAT'
assert ipaddress.ip_address(ip).is_private,'Revise manualmente una dirección pública'
assert not ipaddress.ip_network(network).overlaps(ipaddress.ip_network('192.168.56.0/24')),'La LAN se solapa con host-only; revise las rutas antes de aplicar cambios'
backup=Path('/var/backups/lab5/lan')/str(time.time_ns());backup.mkdir(parents=True)
zone=Path('/etc/bind/zones/db.aerolinea.redes.test');options=Path('/etc/bind/named.conf.options');ftp=Path('/etc/vsftpd.conf')
for f in [zone,options,ftp]:(backup/f.name).write_bytes(f.read_bytes())
text=zone.read_text();text=re.sub(r'(\bIN\s+A\s+)\d+\.\d+\.\d+\.\d+',lambda m:m[1]+ip,text)
serial=re.search(r'(\d+)\s*;\s*[Ss]erial',text)
assert serial,'No se encontró el serial de la zona'
text=text[:serial.start(1)]+str(int(serial[1])+1)+text[serial.end(1):];zone.write_text(text)
text=options.read_text();text=re.sub(r'acl "red-lab"\s*\{[^}]*\};',f'acl "red-lab" {{ localhost; 192.168.56.0/24; {network}; }};',text);options.write_text(text)
ftp.write_text(re.sub(r'^pasv_address=.*$',f'pasv_address={ip}',ftp.read_text(),flags=re.M))
run('named-checkconf');run('named-checkzone','aerolinea.redes.test',str(zone))
state=Path('/var/lib/lab5/lan.json');state.parent.mkdir(parents=True,exist_ok=True)
ports=['22','53','80','389','25','587','143','21','40000:40100']
old=json.loads(state.read_text()) if state.exists() else None
if old and old['network']!=network:
    for port in ports:subprocess.run(['ufw','--force','delete','allow','in','on','enp0s3','from',old['network'],'to','any','port',port,'proto','tcp'],check=True)
    subprocess.run(['ufw','--force','delete','allow','in','on','enp0s3','from',old['network'],'to','any','port','53','proto','udp'],check=True)
subprocess.run(['ufw','--force','delete','allow','in','on','enp0s3','to','any','port','22','proto','tcp'],check=False)
for port in ports:run('ufw','allow','in','on','enp0s3','from',network,'to','any','port',port,'proto','tcp')
run('ufw','allow','in','on','enp0s3','from',network,'to','any','port','53','proto','udp')
run('systemctl','restart','named','vsftpd')
result={'ip':ip,'network':network,'mac':data['address'],'interface':'enp0s3','backup':str(backup)}
state.write_text(json.dumps(result,indent=2));print(json.dumps(result,indent=2))
