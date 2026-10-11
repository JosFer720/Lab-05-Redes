$ErrorActionPreference = "Stop"
$VBoxManage = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (!(Test-Path -LiteralPath $VBoxManage)) { $VBoxManage = (Get-Command VBoxManage.exe -ErrorAction Stop).Source }
$VM = 'CC3067-Lab5-Ubuntu'
Get-NetAdapter | Select-Object Name,Status,MacAddress
Get-NetIPConfiguration
arp -a
& $VBoxManage showvminfo $VM --machinereadable | Select-String 'nic[12]=|macaddress[12]=|hostonlyadapter2='
Test-NetConnection 192.168.56.10 -Port 22
python (Join-Path $PSScriptRoot 'ssh-run.py') --command 'ip -br link; ip -br addr; ip route; ip neigh; resolvectl status'
