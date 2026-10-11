$ErrorActionPreference = "Stop"
$VBoxManage = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (!(Test-Path -LiteralPath $VBoxManage)) { $VBoxManage = (Get-Command VBoxManage.exe -ErrorAction Stop).Source }
$VM = 'CC3067-Lab5-Ubuntu'
$Root = Split-Path $PSScriptRoot -Parent
$Key = Join-Path $Root '.git\virtualbox-private\id_rsa.openssh'
$Known = Join-Path $Root '.git\virtualbox-private\known_hosts'
ssh -i $Key -o "UserKnownHostsFile=$Known" labadmin@192.168.56.10
