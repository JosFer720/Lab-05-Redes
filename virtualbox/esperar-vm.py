#!/usr/bin/env python3
"""Espera a que una VM recién creada responda por SSH, que cloud-init termine y que el adaptador en puente
(enp0s8) reciba su IPv4 por DHCP. Al final imprime tres líneas para que otros scripts las lean:
  LAB_CIDR=192.168.1.32/24
  LAB_IP=192.168.1.32
  LAB_NETWORK=192.168.1.0/24
Uso: python virtualbox/esperar-vm.py [--timeout 900]   (LAB_SSH_HOST, LAB_SSH_PORT y LAB5_PRIVATE_DIR como en ssh-run.py)
"""
import argparse
import importlib.util
import ipaddress
import sys
import time
from pathlib import Path

spec = importlib.util.spec_from_file_location('ssh_run', Path(__file__).with_name('ssh-run.py'))
ssh = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ssh)
IFACE = 'enp0s8'


def say(text):
    print(f'[{time.strftime("%H:%M:%S")}] {text}', flush=True)


def run(client, command, timeout=900):
    _, out, err = client.exec_command(command, timeout=timeout)
    text = out.read().decode(errors='replace') + err.read().decode(errors='replace')
    return out.channel.recv_exit_status(), text.strip()


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--timeout', type=int, default=900)
    args = ap.parse_args()
    deadline = time.monotonic() + args.timeout
    client, attempt = None, 0
    while time.monotonic() < deadline:
        attempt += 1
        try:
            client = ssh.connect()
            say(f'SSH disponible (intento {attempt}).')
            break
        except Exception as exc:
            if attempt % 6 == 1:
                say(f'Esperando a que Ubuntu arranque... ({type(exc).__name__})')
            time.sleep(10)
    if client is None:
        say(f'La VM no respondió por SSH en {args.timeout} s. Mire la consola en VirtualBox (VBoxManage controlvm <VM> screenshotpng).')
        return 1
    try:
        say('Esperando a que cloud-init termine (usuario, llave SSH y red)...')
        code, text = run(client, 'cloud-init status --wait 2>&1 | tail -1', timeout=args.timeout)
        say('cloud-init -> ' + (text or 'sin salida'))
        cidr = ''
        while time.monotonic() < deadline:
            _, cidr = run(client, f"ip -4 -o addr show dev {IFACE} scope global | awk 'NR==1 {{print $4}}'", timeout=30)
            if cidr:
                break
            say(f'Esperando IPv4 por DHCP en {IFACE} (adaptador en puente)...')
            time.sleep(10)
        if not cidr:
            say(f'{IFACE} no obtuvo IP. Revise que el adaptador físico elegido tenga red y que el router entregue DHCP.')
            return 1
        iface = ipaddress.ip_interface(cidr)
        print(f'LAB_CIDR={iface}\nLAB_IP={iface.ip}\nLAB_NETWORK={iface.network}', flush=True)
        return 0
    finally:
        client.close()


if __name__ == '__main__':
    raise SystemExit(main())
