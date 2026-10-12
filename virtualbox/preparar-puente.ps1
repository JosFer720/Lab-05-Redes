param([string]$InterfaceAlias = 'Ethernet')
$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$VBox = Join-Path $env:ProgramFiles 'Oracle/VirtualBox/VBoxManage.exe'
$VM = 'CC3067-Lab5-Ubuntu'
$adapter = Get-NetAdapter -Name $InterfaceAlias
if ($adapter.Status -ne 'Up' -or !$adapter.HardwareInterface) { throw 'Seleccione una interfaz física conectada a la red del profesor.' }
$info = & $VBox showvminfo $VM --machinereadable
if ($LASTEXITCODE) { throw 'No se encontró la VM del laboratorio.' }
if ($info -notcontains 'VMState="poweroff"') {
    throw 'Primero apague Ubuntu de forma segura: sudo systemctl poweroff. No se descartan estados guardados.'
}
$settings = ($info | Where-Object { $_ -match '^CfgFile=' }) -replace '^CfgFile="|"$',''
$backup = Join-Path $Root ('.git/virtualbox-private/puente-backup/' + (Get-Date -Format 'yyyyMMdd-HHmmss') + '.vbox')
New-Item -ItemType Directory -Force (Split-Path $backup -Parent) | Out-Null
Copy-Item -LiteralPath $settings -Destination $backup
$mac = $info | Where-Object { $_ -match '^macaddress1=' }
& $VBox modifyvm $VM --nic1 bridged --bridgeadapter1 $adapter.InterfaceDescription --cableconnected1 on
if ($LASTEXITCODE) { throw 'No se pudo configurar el puente.' }
$after = & $VBox showvminfo $VM --machinereadable
if ($after -notcontains $mac) { throw 'La MAC principal cambió: revise el respaldo antes de arrancar.' }
Write-Output ('Puente sobre ' + $adapter.InterfaceDescription + '; ' + $mac + '; segundo adaptador conservado.')
