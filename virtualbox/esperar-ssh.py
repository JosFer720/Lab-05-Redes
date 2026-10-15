"""Espera el arranque real por SSH; no considera suficiente VMState=running.

Con LAB_REINICIAR_SI_APAGADA=1 (lo pone puente.ps1 iniciar), si durante la espera la VM aparece apagada (poweroff o aborted:
por ejemplo, se estaba apagando cuando se pidio el inicio), la vuelve a encender hasta 2 veces."""
import importlib.util,os,subprocess,time
from pathlib import Path
spec=importlib.util.spec_from_file_location('lab5ssh',Path(__file__).with_name('ssh-run.py'))
ssh=importlib.util.module_from_spec(spec);spec.loader.exec_module(ssh)
VM=os.environ.get('LAB_VM_NAME') or 'CC3067-Lab5-Ubuntu'
VBOX=Path(os.environ.get('ProgramFiles',r'C:\Program Files'))/'Oracle'/'VirtualBox'/'VBoxManage.exe'
REINICIAR=os.environ.get('LAB_REINICIAR_SI_APAGADA')=='1' and VBOX.exists()
def estado():
    try:
        salida=subprocess.run([str(VBOX),'showvminfo',VM,'--machinereadable'],capture_output=True,text=True,timeout=30).stdout
        for linea in salida.splitlines():
            if linea.startswith('VMState='):return linea.split('"')[1]
    except Exception:pass
    return None
reinicios=0
deadline=time.monotonic()+600
while time.monotonic()<deadline:
    try:
        client=ssh.connect()
        _,out,_=client.exec_command('systemctl is-active named slapd apache2 postfix@- dovecot vsftpd',timeout=30)
        active=out.read().decode().splitlines();client.close()
        if active==['active']*6:
            print('SSH disponible; seis servicios nativos activos.');break
    except Exception:pass
    if REINICIAR and reinicios<2 and estado() in ('poweroff','aborted'):
        reinicios+=1
        print('La VM esta apagada (se estaba apagando o se cerro): se enciende de nuevo...',flush=True)
        subprocess.run([str(VBOX),'startvm',VM,'--type','headless'])
    print('Esperando Ubuntu y sus servicios...',flush=True);time.sleep(10)
else:raise SystemExit('Ubuntu no recuperó SSH y seis servicios en diez minutos.')
