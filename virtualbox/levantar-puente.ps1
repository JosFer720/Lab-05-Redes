<#
 Levanta el Laboratorio 5 completo (DNS, LDAP, web, correo y FTP) en una VM Ubuntu nueva de VirtualBox con
 red en puente, para que otras computadoras de la misma red lo usen. Es el comando de la primera vez en una PC.

 Hace, en orden: comprobar requisitos -> generar credenciales -> crear la VM -> esperar a que arranque y reciba IP
 por DHCP -> instalar y configurar los cinco servicios -> mostrar IP, MAC y como conectarse.
 Si la VM ya existe y sus seis servicios estan activos no reinstala nada (use -Forzar para reinstalar).

 Uso (desde la raiz del repositorio, en PowerShell):
   powershell -ExecutionPolicy Bypass -File virtualbox/levantar-puente.ps1
   powershell -ExecutionPolicy Bypass -File virtualbox/levantar-puente.ps1 -Adaptador "Intel(R) Wi-Fi 6E AX211 160MHz"

 Parametros:
   -Adaptador  adaptador fisico del puente, con el nombre exacto de:  VBoxManage list bridgedifs
               (predeterminado: el primero activo con IP; elija el Wi-Fi si los demas usan Wi-Fi).
   -Forzar     reinstala los servicios aunque ya esten activos.
 Variables opcionales: LAB5_PRIVATE_DIR (secretos; predeterminado %USERPROFILE%\.lab5-private),
 LAB_VM_NAME y LAB_NAT_SSH_PORT (nombre de la VM y puerto local de SSH; solo para tener una segunda VM).
 Requisitos: VirtualBox 7.x, Python 3.11+ y  python -m pip install paramiko pycdlib.
#>
param([string]$Adaptador, [switch]$Forzar)
$ErrorActionPreference = 'Stop'
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
$VM = if ($env:LAB_VM_NAME) { $env:LAB_VM_NAME } else { 'CC3067-Lab5-Ubuntu' }
$SshPort = if ($env:LAB_NAT_SSH_PORT) { $env:LAB_NAT_SSH_PORT } else { '22225' }
$Priv = if ($env:LAB5_PRIVATE_DIR) { $env:LAB5_PRIVATE_DIR } else { Join-Path $env:USERPROFILE '.lab5-private' }
$Aqui = $PSScriptRoot

function Paso([string]$Texto) { Write-Host "`n== $Texto ==" -ForegroundColor Cyan }
function Py([string]$Script, [string[]]$Argumentos = @()) {
    & python (Join-Path $Aqui $Script) @Argumentos
    if ($LASTEXITCODE) { throw "Fallo $Script (codigo $LASTEXITCODE). Lea el mensaje anterior." }
}
function Remoto([string]$Comando) { (& python (Join-Path $Aqui 'ssh-run.py') --command $Comando) -join "`n" }
function Registrada { [bool]((& $VBox list vms) -match ('"' + [regex]::Escape($VM) + '"')) }
function EnMarcha { [bool]((& $VBox list runningvms) -match ('"' + [regex]::Escape($VM) + '"')) }

Paso 'Requisitos'
if (-not (Test-Path -LiteralPath $VBox)) { throw 'No encuentro VirtualBox en C:\Program Files\Oracle\VirtualBox. Instale VirtualBox 7.x desde virtualbox.org.' }
if (-not (Get-Command python -ErrorAction SilentlyContinue)) { throw 'No encuentro python. Instale Python 3.11 o superior (python.org) marcando "Add python.exe to PATH".' }
& python -c "import sys; sys.exit(0 if sys.version_info >= (3, 11) else 1)"
if ($LASTEXITCODE) { throw 'Se necesita Python 3.11 o superior.' }
& python -c "import paramiko, pycdlib"
if ($LASTEXITCODE) { throw 'Faltan paquetes de Python. Ejecute:  python -m pip install paramiko pycdlib' }
$libre = (Get-PSDrive -Name $env:USERPROFILE.Substring(0, 1)).Free / 1GB
if ($libre -lt 10) { throw ('Espacio libre insuficiente en la unidad del usuario: {0:N1} GB (se necesitan unos 10 GB).' -f $libre) }
Write-Host ('VirtualBox: ' + (& $VBox --version) + '   espacio libre: {0:N0} GB' -f $libre)
$env:LAB5_PRIVATE_DIR = $Priv
$env:LAB_NET_MODE = 'bridged'
$env:LAB_SSH_HOST = '127.0.0.1'
$env:LAB_SSH_PORT = $SshPort
$env:LAB_NAT_SSH_PORT = $SshPort
$env:LAB_VM_NAME = $VM
if ($Adaptador) { $env:LAB_BRIDGE_ADAPTER = $Adaptador }
Write-Host "Carpeta de secretos (fuera de Git y de OneDrive): $Priv"
Write-Host ('Adaptador del puente: ' + $(if ($env:LAB_BRIDGE_ADAPTER) { $env:LAB_BRIDGE_ADAPTER } else { '(automatico: el primero activo con IP; ver VBoxManage list bridgedifs)' }))

Paso 'Credenciales'
Py 'generar-credenciales.py'

Paso 'Maquina virtual'
if (-not (Registrada)) {
    Write-Host 'Creando la VM (descarga la imagen oficial de Ubuntu de ~600 MB la primera vez y verifica su SHA256)...'
    Py 'crear-ubuntu.py'
} elseif (-not (EnMarcha)) {
    Write-Host 'La VM ya existe: encendiendola.'
    & $VBox startvm $VM --type headless
    if ($LASTEXITCODE) { throw 'No se pudo encender la VM.' }
} else {
    Write-Host 'La VM ya existe y esta encendida.'
}

Paso 'Esperando el arranque (con el motor NEM de VirtualBox puede tardar 4 a 8 minutos)'
$salida = @()
& python (Join-Path $Aqui 'esperar-vm.py') | ForEach-Object { Write-Host $_; $salida += $_ }
if ($LASTEXITCODE) { throw 'La VM no quedo lista; vea el mensaje anterior.' }
$datos = @{}
foreach ($linea in $salida) { if ($linea -match '^(LAB_[A-Z]+)=(.+)$') { $datos[$Matches[1]] = $Matches[2] } }
if (-not $datos.LAB_IP -or -not $datos.LAB_NETWORK) { throw 'No pude leer la IP de la VM.' }

$activos = (Remoto 'systemctl is-active named slapd apache2 postfix@- dovecot vsftpd 2>/dev/null; true') -split "`n" | Where-Object { $_ -eq 'active' }
if (@($activos).Count -eq 6 -and -not $Forzar) {
    Write-Host 'Los seis servicios ya estan activos: no se reinstala nada (use -Forzar para reinstalar).' -ForegroundColor Green
} else {
    Paso ('Instalando los servicios en ' + $datos.LAB_IP + ' (10 a 25 minutos: apt, compilar el sitio React, configurar LDAP y correo)')
    $env:LAB_IP = $datos.LAB_IP
    $env:LAB_NETWORK = $datos.LAB_NETWORK
    $env:LAB_IFACE = 'enp0s8'
    $env:LAB_RESOLVER = '127.0.0.1'
    $env:LAB_PORTS = '53 80 389 25 587 143 21'
    Py 'desplegar.py'
    Py 'esperar-ssh.py'
}

Paso 'Resumen'
$info = & $VBox showvminfo $VM --machinereadable
function Mac([int]$n) { $m = ($info | Select-String "^macaddress$n=`"(\w+)`"").Matches[0].Groups[1].Value; (($m -split '(..)' | Where-Object { $_ }) -join ':') }
$ip = ((Remoto "ip -4 -o addr show dev enp0s8 scope global | awk '{print `$4}'") -split '/')[0]
$cred = Join-Path $Priv 'lab5-private\credentials.json'
Write-Host ''
Write-Host "  IP de los servicios en la red:  $ip   (esta es la IP que los demas ponen como DNS)" -ForegroundColor Green
Write-Host ('  MAC de la VM (adaptador en puente): ' + (Mac 2))
Write-Host ('  MAC del adaptador NAT (interno):    ' + (Mac 1))
Write-Host "  Credenciales para los companeros:   $cred   (entreguelas por un canal privado)"
Write-Host ''
Write-Host '  Dia a dia:  powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar | estado | ip | mac | ssh | detener'
Write-Host '  Si cambia la red o la IP:  puente.ps1 ssh "sudo bash /opt/lab5/virtualbox/cambiar-ip.sh"  y avisar la IP nueva'
Write-Host '  Para que no se suspenda la PC mientras la usan:  powercfg /change standby-timeout-ac 0'
