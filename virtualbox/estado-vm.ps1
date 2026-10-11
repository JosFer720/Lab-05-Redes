$ErrorActionPreference = "Stop"
$VBoxManage = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (!(Test-Path -LiteralPath $VBoxManage)) { $VBoxManage = (Get-Command VBoxManage.exe -ErrorAction Stop).Source }
$VM = 'CC3067-Lab5-Ubuntu'
& $VBoxManage showvminfo $VM --details
