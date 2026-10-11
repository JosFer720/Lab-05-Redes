#!/usr/bin/env python3
"""Crea Ubuntu 24.04 VirtualBox desde VMDK oficial verificado y semilla NoCloud.
No usa contenedores ni WSL. No modifica VMs existentes.
Requiere: pip install paramiko pycdlib
"""
import hashlib,io,json,subprocess,urllib.request,shutil,os
from pathlib import Path
import paramiko,pycdlib
ROOT=Path(__file__).resolve().parent.parent
PRIVATE=ROOT/'.git/virtualbox-private'
VBOX=Path('C:/Program Files/Oracle/VirtualBox/VBoxManage.exe')
NAME='CC3067-Lab5-Ubuntu'
DEST=Path.home()/'VirtualBox VMs'/NAME
def vbox(*args):
    p=subprocess.run([str(VBOX),*map(str,args)],capture_output=True,text=True)
    if p.returncode: raise RuntimeError(p.stderr)
    print(p.stdout.strip(),flush=True)
    return p.stdout
def main():
    if NAME in vbox('list','vms'):
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
    user_data=f'''#cloud-config
hostname: lab5-ubuntu
manage_etc_hosts: false
users:
  - name: labadmin
    groups: [adm, sudo]
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    lock_passwd: true
    ssh_authorized_keys:
      - {key.get_name()} {key.get_base64()}
ssh_pwauth: false
disable_root: true
write_files:
    - path: /etc/default/grub.d/99-lab5-timer.cfg
      content: 'GRUB_CMDLINE_LINUX_DEFAULT="quiet noapic clocksource=acpi_pm"'
  - path: /etc/cloud/cloud.cfg.d/99-disable-network-config.cfg
    content: 'network: {{config: disabled}}'
  - path: /etc/netplan/60-lab5.yaml
    permissions: '0600'
    content: |
      network:
        version: 2
        ethernets:
          enp0s3:
            dhcp4: true
          enp0s8:
            dhcp4: false
            addresses: [192.168.56.10/24]
runcmd:
    - [update-grub]
  - [netplan, apply]
  - [systemctl, enable, --now, ssh]
'''
    seed=pycdlib.PyCdlib(); seed.new(interchange_level=3,joliet=3,vol_ident='cidata')
    for name,data,iso in [('user-data',user_data,'/USERDATA.;1'),('meta-data','instance-id: lab5-vbox-20261011\nlocal-hostname: lab5-ubuntu\n','/METADATA.;1')]:
        encoded=data.encode(); seed.add_fp(io.BytesIO(encoded),len(encoded),iso_path=iso,joliet_path='/'+name)
    seed.write(str(PRIVATE/'seed.iso')); seed.close()
    DEST.mkdir(parents=True,exist_ok=True)
    disk=DEST/'Ubuntu24.vdi'
    vbox('clonemedium','disk',image,disk,'--format','VDI')
    vbox('modifymedium','disk',disk,'--resize','25600')
    vbox('createvm','--name',NAME,'--ostype','Ubuntu_64','--register')
    vbox('modifyvm',NAME,'--memory','1536','--cpus','1','--firmware','bios','--graphicscontroller','vmsvga','--vram','16',
         '--ioapic','on','--x2apic','off','--hpet','on','--paravirtprovider','none','--nictype1','virtio','--nictype2','virtio',
         '--nic1','nat','--nic2','hostonly','--hostonlyadapter2','VirtualBox Host-Only Ethernet Adapter',
         '--natpf1','lab5-ssh,tcp,127.0.0.1,22225,,22','--boot1','disk')
    vbox('storagectl',NAME,'--name','SATA','--add','sata','--controller','IntelAhci')
    vbox('storagectl',NAME,'--name','SATA','--portcount','2')
    vbox('storageattach',NAME,'--storagectl','SATA','--port','0','--device','0','--type','hdd','--medium',disk)
    vbox('storageattach',NAME,'--storagectl','SATA','--port','1','--device','0','--type','dvddrive','--medium',PRIVATE/'seed.iso')
    (PRIVATE/'vm.json').write_text(json.dumps({'name':NAME,'ip':'192.168.56.10','ssh_user':'labadmin','ssh_key':str(key_file),'image_sha256':observed,'source':base+'noble-server-cloudimg-amd64.vmdk'}))
    vbox('startvm',NAME,'--type','headless')
if __name__=='__main__': main()
