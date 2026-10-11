"""Espera el arranque real por SSH; no considera suficiente VMState=running."""
import importlib.util,time
from pathlib import Path
spec=importlib.util.spec_from_file_location('lab5ssh',Path(__file__).with_name('ssh-run.py'))
ssh=importlib.util.module_from_spec(spec);spec.loader.exec_module(ssh)
deadline=time.monotonic()+600
while time.monotonic()<deadline:
    try:
        client=ssh.connect()
        _,out,_=client.exec_command('systemctl is-active named slapd apache2 postfix@- dovecot vsftpd',timeout=30)
        active=out.read().decode().splitlines();client.close()
        if active==['active']*6:
            print('SSH disponible; seis servicios nativos activos.');break
    except Exception:pass
    print('Esperando Ubuntu y sus servicios...',flush=True);time.sleep(10)
else:raise SystemExit('Ubuntu no recuperó SSH y seis servicios en diez minutos.')
