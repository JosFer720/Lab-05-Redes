#!/usr/bin/env python3
"""Crea Ubuntu 24.04 VirtualBox desde VMDK oficial verificado y semilla NoCloud.
No usa contenedores ni WSL. No modifica VMs existentes.
Requiere: pip install paramiko pycdlib

Red, según la variable de entorno LAB_NET_MODE:
  hostonly (predeterminado)  NAT + host-only 192.168.56.10/24: solo esta computadora ve la VM.
  bridged                    NAT + adaptador en puente con IP por DHCP: la VM aparece en la red
                             local del equipo físico y otros equipos pueden alcanzarla.
                             LAB_BRIDGE_ADAPTER fija el adaptador físico; si no se define se
                             usa el primero activo que tenga IP.
"""
import hashlib,io,json,re,subprocess,urllib.request,shutil,os
from pathlib import Path
import paramiko,pycdlib
ROOT=Path(__file__).resolve().parent.parent
# Secretos (clave SSH, imagen, semilla) fuera del control de versiones: por defecto dentro de .git/.
# LAB5_PRIVATE_DIR los guarda en otra carpeta, por ejemplo fuera de OneDrive u otra carpeta sincronizada.
PRIVATE=(Path(os.environ['LAB5_PRIVATE_DIR']) if os.environ.get('LAB5_PRIVATE_DIR') else ROOT/'.git')/'virtualbox-private'
VBOX=Path('C:/Program Files/Oracle/VirtualBox/VBoxManage.exe')
NAME=os.environ.get('LAB_VM_NAME','CC3067-Lab5-Ubuntu')
NAT_SSH_PORT=os.environ.get('LAB_NAT_SSH_PORT','22225')  # puerto del anfitrión que reenvía al SSH de la VM
DEST=Path.home()/'VirtualBox VMs'/NAME
NET_MODE=os.environ.get('LAB_NET_MODE','hostonly')
if NET_MODE not in ('hostonly','bridged'): raise SystemExit('LAB_NET_MODE debe ser hostonly o bridged')
# Con Hyper-V/WSL2 activos (VirtualBox usa el motor NEM), algunos equipos Windows hacen que el kernel
# entre en pánico en el primer arranque: "IO-APIC + timer doesn't work!". La VM usa una sola CPU, así
# que el IO-APIC no hace falta: apagado por defecto (equivale a 'noapic'). LAB_IOAPIC=on restaura el original.
IOAPIC=os.environ.get('LAB_IOAPIC','off')
if IOAPIC not in ('on','off'): raise SystemExit('LAB_IOAPIC debe ser on u off')

USER_DATA_HEAD='''#cloud-config
hostname: lab5-ubuntu
manage_etc_hosts: false
users:
  - name: labadmin
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - @KEY@
ssh_pwauth: false
disable_root: true
write_files:
  - path: /etc/default/grub.d/99-lab5-timer.cfg
    content: 'GRUB_CMDLINE_LINUX_DEFAULT="quiet noapic clocksource=acpi_pm"'
  - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    content: 'network: {config: disabled}'
  - path: /etc/netplan/60-lab5.yaml
    permissions: '0600'
    content: |
'''
USER_DATA_TAIL='''runcmd:
  - [update-grub]
  - [netplan, apply]
  - [systemctl, enable, --now, ssh]
'''
def vbox(*args):
    p=subprocess.run([str(VBOX),*map(str,args)],capture_output=True,text=True)
    if p.returncode: raise RuntimeError(p.stderr)
    print(p.stdout.strip(),flush=True)
    return p.stdout
def bridge_adapter():
    """Adaptador físico para el modo puente: LAB_BRIDGE_ADAPTER o el primero activo con IP."""
    if os.environ.get('LAB_BRIDGE_ADAPTER'): return os.environ['LAB_BRIDGE_ADAPTER']
    listing=subprocess.run([str(VBOX),'list','bridgedifs'],capture_output=True,text=True,check=True).stdout
    for block in listing.split('\n\n'):
        fields=dict(re.findall(r'^(\w+):\s+(.*?)\s*$',block,re.M))
        if fields.get('Status')=='Up' and fields.get('IPAddress','0.0.0.0')!='0.0.0.0': return fields['Name']
    raise RuntimeError('No hay adaptador físico activo para el modo puente; defina LAB_BRIDGE_ADAPTER')
def netplan_text():
    if NET_MODE=='bridged':
        # El puente va primero como ruta predeterminada (métrica menor que la NAT, que queda en 100);
        # NAT queda para administración y respaldo. No se tocan las métricas de enp0s3: cloud-init
        # le activa DHCPv6 y netplan exige métricas iguales en dhcp4 y dhcp6 cuando se sobrescriben.
        return ('network:\n  version: 2\n  ethernets:\n'
                '    enp0s3:\n      dhcp4: true\n'
                '    enp0s8:\n      dhcp4: true\n      dhcp4-overrides:\n        route-metric: 50\n')
    return ('network:\n  version: 2\n  ethernets:\n'
            '    enp0s3:\n      dhcp4: true\n'
            '    enp0s8:\n      dhcp4: false\n      addresses: [192.168.56.10/24]\n')
def build_user_data(public_key):
    netplan=''.join('      '+line+'\n' for line in netplan_text().splitlines())
    return USER_DATA_HEAD.replace('@KEY@',public_key)+netplan+USER_DATA_TAIL
def main():
    if '"'+NAME+'"' in vbox('list','vms'):
        print('VM existente conservada; no se recrea'); return
    PRIVATE.mkdir(parents=True,exist_ok=True)
    base='https://cloud-images.ubuntu.com/noble/20260725/'
    image=PRIVATE/'ubuntu24-julio.vmdk'
    sums=PRIVATE/'SHA256SUMS-julio'
    if not sums.exists():
        with urllib.request.urlopen(base+'SHA256SUMS',timeout=60) as r: sums.write_bytes(r.read())
    if not image.exists():
        with urllib.request.urlopen(base+'noble-server-cloudimg-amd64.vmdk',timeout=60) as r,image.open('wb') as f: shutil.copyfileobj(r,f)
    expected=next(line.split()[0] for line in sums.read_text().splitlines() if line.endswith('noble-server-cloudimg-amd64.vmdk'))
    observed=hashlib.file_digest(image.open('rb'),'sha256').hexdigest()
    assert observed==expected,'Checksum de imagen incorrecto'
    key_file=PRIVATE/'id_rsa'
    if key_file.exists(): key=paramiko.RSAKey.from_private_key_file(str(key_file))
    else:
        key=paramiko.RSAKey.generate(3072); key.write_private_key_file(str(key_file))
        (PRIVATE/'id_rsa.pub').write_text(key.get_name()+' '+key.get_base64()+' lab5-native\n')
    openssh=PRIVATE/'id_rsa.openssh'
    if not openssh.exists():
        shutil.copy2(key_file,openssh)
        identity=os.environ['USERDOMAIN']+'\\'+os.environ['USERNAME']
        subprocess.run(['icacls',str(openssh),'/inheritance:r','/grant:r',identity+':(F)','*S-1-5-18:(F)','*S-1-5-32-544:(F)'],check=True,capture_output=True)
    user_data=build_user_data(key.get_name()+' '+key.get_base64())
    seed=pycdlib.PyCdlib(); seed.new(interchange_level=3,joliet=3,vol_ident='cidata')
    for name,data,iso in [('user-data',user_data,'/USERDATA.;1'),('meta-data','instance-id: lab5-vbox-20261011\nlocal-hostname: lab5-ubuntu\n','/METADATA.;1')]:
        encoded=data.encode(); seed.add_fp(io.BytesIO(encoded),len(encoded),iso_path=iso,joliet_path='/'+name)
    seed.write(str(PRIVATE/'seed.iso')); seed.close()
    DEST.mkdir(parents=True,exist_ok=True)
    disk=DEST/'Ubuntu24.vdi'
    vbox('clonemedium','disk',image,disk,'--format','VDI')
    vbox('modifymedium','disk',disk,'--resize','25600')
    vbox('createvm','--name',NAME,'--ostype','Ubuntu_64','--register')
    if NET_MODE=='bridged': nic2=['--nic2','bridged','--bridgeadapter2',bridge_adapter()]
    else: nic2=['--nic2','hostonly','--hostonlyadapter2','VirtualBox Host-Only Ethernet Adapter']
    vbox('modifyvm',NAME,'--memory','1536','--cpus','1','--firmware','bios','--graphicscontroller','vmsvga','--vram','16',
         '--ioapic',IOAPIC,'--x2apic','off','--hpet','on','--paravirtprovider','none','--nictype1','virtio','--nictype2','virtio',
         '--nic1','nat',*nic2,
         '--natpf1','lab5-ssh,tcp,127.0.0.1,'+NAT_SSH_PORT+',,22','--boot1','disk')
    # VirtualBox 7.2 interpreta '--x2apic off' dejando el APIC principal apagado y no arranca un
    # invitado de 64 bits ("Cannot disable the APIC"). Se activa; x2APIC sigue apagado. En
    # versiones anteriores la opción '--apic' puede no existir: ya estaba activo, se ignora.
    try: vbox('modifyvm',NAME,'--apic','on')
    except RuntimeError: pass
    vbox('storagectl',NAME,'--name','SATA','--add','sata','--controller','IntelAhci')
    vbox('storagectl',NAME,'--name','SATA','--portcount','2')
    vbox('storageattach',NAME,'--storagectl','SATA','--port','0','--device','0','--type','hdd','--medium',disk)
    vbox('storageattach',NAME,'--storagectl','SATA','--port','1','--device','0','--type','dvddrive','--medium',PRIVATE/'seed.iso')
    (PRIVATE/'vm.json').write_text(json.dumps({'name':NAME,'net_mode':NET_MODE,'ip':'192.168.56.10' if NET_MODE=='hostonly' else None,'ssh_user':'labadmin','ssh_key':str(key_file),'image_sha256':observed,'source':base+'noble-server-cloudimg-amd64.vmdk'}))
    vbox('startvm',NAME,'--type','headless')
if __name__=='__main__': main()
