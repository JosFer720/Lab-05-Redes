<#
 Atajos para la VM CC3067-Lab5-Ubuntu creada en modo puente (LAB_NET_MODE=bridged).
 Configura solo para este script las variables que necesitan los demas scripts de virtualbox/.

 Uso (desde la raiz del repositorio):
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar    enciende la VM y espera SSH y los 6 servicios
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 estado     estado de la VM, IP en la red y servicios
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 ip         IP que la VM recibio en la red local
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 mac        MAC de cada adaptador
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 ssh        abre una sesion SSH (o: ssh <comando>)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 traer <ruta-en-la-VM> [destino]   copia un archivo o carpeta de la VM a Windows
                                                                          (destino predeterminado: %USERPROFILE%\lab5-evidencias\vm)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 detener    apagado normal (ACPI)

 Los secretos estan en LAB5_PRIVATE_DIR (por defecto %USERPROFILE%\.lab5-private).
 Si la VM tiene otro nombre o puerto SSH: LAB_VM_NAME y LAB_NAT_SSH_PORT (los mismos que uso crear-ubuntu.py).
#>
param(
    [Parameter(Position = 0)][ValidateSet('iniciar', 'estado', 'ip', 'mac', 'ssh', 'traer', 'detener')][string]$Accion = 'estado',
    [Parameter(Position = 1, ValueFromRemainingArguments = $true)][string[]]$Resto
)
$ErrorActionPreference = 'Stop'
$VBox = Join-Path $env:ProgramFiles 'Oracle\VirtualBox\VBoxManage.exe'
if (!(Test-Path -LiteralPath $VBox)) { $VBox = (Get-Command VBoxManage.exe -ErrorAction Stop).Source }
$VM = if ($env:LAB_VM_NAME) { $env:LAB_VM_NAME } else { 'CC3067-Lab5-Ubuntu' }
$SshPort = if ($env:LAB_NAT_SSH_PORT) { $env:LAB_NAT_SSH_PORT } else { '22225' }
$Priv = if ($env:LAB5_PRIVATE_DIR) { $env:LAB5_PRIVATE_DIR } else { Join-Path $env:USERPROFILE '.lab5-private' }
$env:LAB5_PRIVATE_DIR = $Priv
$env:LAB_SSH_HOST = '127.0.0.1'
$env:LAB_SSH_PORT = $SshPort
$SshRun = Join-Path $PSScriptRoot 'ssh-run.py'

function Test-Running { [bool]((& $VBox list runningvms) -match [regex]::Escape($VM)) }
function Invoke-Remote([string]$Command) { python $SshRun --command $Command }
function Get-Macs {
    $info = & $VBox showvminfo $VM --machinereadable
    foreach ($n in 1, 2) {
        $raw = ($info | Select-String "^macaddress$n=`"(\w+)`"").Matches[0].Groups[1].Value
        $mode = ($info | Select-String "^nic$n=`"(\w+)`"").Matches[0].Groups[1].Value
        [pscustomobject]@{ Adaptador = "NIC$n"; Modo = $mode; MAC = (($raw -split '(..)' | Where-Object { $_ }) -join ':') }
    }
}

switch ($Accion) {
    'iniciar' {
        if (-not (Test-Running)) { & $VBox startvm $VM --type headless }
        python (Join-Path $PSScriptRoot 'esperar-ssh.py')
        Invoke-Remote "ip -4 -br addr show enp0s8"
    }
    'estado' {
        & $VBox showvminfo $VM --machinereadable | Select-String '^VMState='
        if (Test-Running) {
            Invoke-Remote "ip -4 -br addr; systemctl is-active named slapd apache2 postfix@- dovecot vsftpd"
        }
    }
    'ip' { Invoke-Remote "ip -4 -o addr show dev enp0s8 scope global | awk '{print `$4}'" }
    'mac' { Get-Macs | Format-Table -AutoSize }
    'ssh' {
        $key = Join-Path $Priv 'virtualbox-private\id_rsa.openssh'
        $known = Join-Path $Priv 'virtualbox-private\known_hosts'
        ssh -i $key -p $SshPort -o "UserKnownHostsFile=$known" labadmin@127.0.0.1 @Resto
    }
    'traer' {
        if (-not $Resto) { throw 'Uso: puente.ps1 traer <ruta-en-la-VM> [destino-en-Windows]' }
        $remoto = $Resto[0]
        $destino = if ($Resto.Count -ge 2) { $Resto[1] } else { Join-Path $env:USERPROFILE 'lab5-evidencias\vm' }
        # Sin extension se trata como carpeta (se crea); con extension, como archivo (se crea su carpeta).
        $carpeta = if ([IO.Path]::GetExtension($destino)) { Split-Path -Parent $destino } else { $destino }
        if ($carpeta) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }
        $key = Join-Path $Priv 'virtualbox-private\id_rsa.openssh'
        $known = Join-Path $Priv 'virtualbox-private\known_hosts'
        scp -r -i $key -P $SshPort -o "UserKnownHostsFile=$known" "labadmin@127.0.0.1:$remoto" $destino
        if ($LASTEXITCODE) { throw 'scp fallo: revise la ruta dentro de la VM (los archivos deben ser legibles por labadmin).' }
        Write-Host "Copiado a $destino"
    }
    'detener' {
        & $VBox controlvm $VM acpipowerbutton
        if ($LASTEXITCODE) { throw 'No se pudo solicitar el apagado normal.' }
    }
}
