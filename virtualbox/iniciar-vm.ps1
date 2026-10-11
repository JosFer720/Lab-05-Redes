$ErrorActionPreference = "Stop"
$VBoxManage = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (!(Test-Path -LiteralPath $VBoxManage)) { $VBoxManage = (Get-Command VBoxManage.exe -ErrorAction Stop).Source }
$VM = 'CC3067-Lab5-Ubuntu'
$state = & $VBoxManage showvminfo $VM --machinereadable
if ($LASTEXITCODE) { throw 'VM ausente. Consulte crear-ubuntu.py.' }
if ($state -notcontains 'VMState="running"') { & $VBoxManage startvm $VM --type headless }
python (Join-Path $PSScriptRoot 'esperar-ssh.py')
if ($LASTEXITCODE) { throw 'Ubuntu no está listo; revise la consola y el estado SSH.' }
