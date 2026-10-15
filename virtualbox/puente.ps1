<#
 Atajos para la VM CC3067-Lab5-Ubuntu creada en modo puente (LAB_NET_MODE=bridged).
 Configura solo para este script las variables que necesitan los demas scripts de virtualbox/.

 Uso (desde la raiz del repositorio; todo funciona SIN Internet):
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar    enciende la VM, espera SSH, los 6 servicios y la IP de la red
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 estado     estado de la VM, IP en la red y servicios
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 ip         IP que la VM recibio en la red local
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 mac        MAC de cada adaptador
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 verificar  comprueba que ns1 (puerto 53 UDP y TCP, firewall, zona) esta listo y que los servicios de la zona responden
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 ips ldap=<IP> www=<IP> mail=<IP> ftp=<IP>   carga las IPs de los companeros en la zona
                                                                         (lo no indicado conserva su valor; nombre=vm lo devuelve a esta VM; "ips --todo-en-la-vm"
                                                                         devuelve los cinco; "ips --simular ..." solo muestra; sin argumentos reajusta a la red actual)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 entregables [carpeta]   reune zona, tabla, evidencias y verificacion de la parte DNS en Windows
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 respaldar [--dejar-apagada]   apaga la VM y la exporta a un .ova (restaurable sin Internet)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 importar <respaldo.ova>        restaura la VM desde un .ova (en esta u otra PC con VirtualBox)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 kit [carpeta] [--con-ova]      junta guias, paquete, llaves y credenciales para llevar (USB)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 ssh        abre una sesion SSH (o: ssh <comando>)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 traer <ruta-en-la-VM> [destino]   copia un archivo o carpeta de la VM a Windows
                                                                          (destino predeterminado: %USERPROFILE%\lab5-evidencias\vm)
   powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 detener    apagado normal (ACPI)

 Los secretos estan en LAB5_PRIVATE_DIR (por defecto %USERPROFILE%\.lab5-private).
 Si la VM tiene otro nombre o puerto SSH: LAB_VM_NAME y LAB_NAT_SSH_PORT (los mismos que uso crear-ubuntu.py).
#>
param(
    [Parameter(Position = 0)][ValidateSet('iniciar', 'estado', 'ip', 'mac', 'verificar', 'ips', 'entregables', 'respaldar', 'importar', 'kit', 'ssh', 'traer', 'detener')][string]$Accion = 'estado',
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
$KeyFile = Join-Path $Priv 'virtualbox-private\id_rsa.openssh'
$KnownHosts = Join-Path $Priv 'virtualbox-private\known_hosts'

function Test-Registered { [bool]((& $VBox list vms) -match ('"' + [regex]::Escape($VM) + '"')) }
function Test-Running { [bool]((& $VBox list runningvms) -match [regex]::Escape($VM)) }
function Get-VmState { ((& $VBox showvminfo $VM --machinereadable) | Select-String '^VMState="(\w+)"').Matches[0].Groups[1].Value }
function Wait-VmState([string]$Estado, [int]$Segundos) {
    $fin = (Get-Date).AddSeconds($Segundos)
    while ((Get-Date) -lt $fin) { if ((Get-VmState) -eq $Estado) { return $true }; Start-Sleep -Seconds 3 }
    return $false
}
function Invoke-Remote([string]$Command) { python $SshRun --command $Command }
function Get-Macs {
    $info = & $VBox showvminfo $VM --machinereadable
    foreach ($n in 1, 2) {
        $raw = ($info | Select-String "^macaddress$n=`"(\w+)`"").Matches[0].Groups[1].Value
        $mode = ($info | Select-String "^nic$n=`"(\w+)`"").Matches[0].Groups[1].Value
        [pscustomobject]@{ Adaptador = "NIC$n"; Modo = $mode; MAC = (($raw -split '(..)' | Where-Object { $_ }) -join ':') }
    }
}
# Adaptadores fisicos que VirtualBox ve (nombre, estado, IP) para el modo puente.
function Get-BridgeIfs {
    $bloques = (& $VBox list bridgedifs | Out-String) -split "(?:\r?\n){2,}"
    foreach ($b in $bloques) {
        $campos = @{}
        foreach ($l in ($b -split "\r?\n")) { if ($l -match '^(\w+):\s+(.*?)\s*$') { $campos[$Matches[1]] = $Matches[2] } }
        if ($campos.Name) { [pscustomobject]@{ Nombre = $campos.Name; Estado = $campos.Status; IP = $campos.IPAddress } }
    }
}
function Copy-FromVm([string]$Remoto, [string]$Destino) {
    # Sin extension se trata como carpeta (se crea); con extension, como archivo (se crea su carpeta).
    $carpeta = if ([IO.Path]::GetExtension($Destino)) { Split-Path -Parent $Destino } else { $Destino }
    if ($carpeta) { New-Item -ItemType Directory -Force -Path $carpeta | Out-Null }
    scp -r -i $KeyFile -P $SshPort -o "UserKnownHostsFile=$KnownHosts" "labadmin@127.0.0.1:$Remoto" $Destino
    if ($LASTEXITCODE) { throw 'scp fallo: revise la ruta dentro de la VM (los archivos deben ser legibles por labadmin).' }
}

switch ($Accion) {
    'iniciar' {
        if (-not (Test-Registered)) { throw "No existe la VM $VM en este VirtualBox. Si tiene un respaldo: puente.ps1 importar <respaldo.ova>" }
        # El adaptador fisico del puente debe tener red ANTES de encender la VM; si no, la VM no recibe IP (aunque luego se conecte el Wi-Fi).
        $bridge = ((& $VBox showvminfo $VM --machinereadable) | Select-String '^bridgeadapter2="(.*)"').Matches[0].Groups[1].Value
        $fisico = Get-BridgeIfs | Where-Object { $_.Nombre -eq $bridge } | Select-Object -First 1
        if (-not $fisico -or $fisico.Estado -ne 'Up' -or $fisico.IP -eq '0.0.0.0') {
            Write-Warning "El adaptador del puente '$bridge' no tiene red ahora. Conecte el Wi-Fi (el aviso 'sin Internet' es normal) y, si la VM ya esta encendida, corra: puente.ps1 ssh `"sudo netplan apply`""
        } else {
            Write-Host "Red de esta PC: $($fisico.IP) por '$bridge'"
        }
        if (-not (Test-Running)) { & $VBox startvm $VM --type headless }
        # Si la VM estaba apagandose cuando se llamo a "iniciar" (detener recien ejecutado), esperar-ssh.py la vuelve a encender al verla apagada.
        $env:LAB_REINICIAR_SI_APAGADA = '1'
        python (Join-Path $PSScriptRoot 'esperar-ssh.py')
        if ($LASTEXITCODE) {
            throw ("La VM no respondio por SSH en 10 minutos (estado: $(Get-VmState)). No es el Wi-Fi si el estado es poweroff: ejecute puente.ps1 iniciar de nuevo. " +
                   "Si el estado es running, mire la pantalla: VBoxManage controlvm $VM screenshotpng `"`$env:TEMP\vm.png`" (guia, seccion C.2).")
        }
        $cidr = ''
        for ($i = 0; $i -lt 18 -and -not $cidr; $i++) {
            $cidr = ((Invoke-Remote "ip -4 -o addr show dev enp0s8 scope global | awk 'NR==1 {print `$4}'") -join '').Trim()
            if (-not $cidr) { Write-Host 'Esperando IP por DHCP en el adaptador en puente...'; Start-Sleep -Seconds 5 }
        }
        if ($cidr) {
            Write-Host ''
            Write-Host "IP de ns1 (la que usan los demas como DNS): $($cidr.Split('/')[0])   red $cidr" -ForegroundColor Green
            Write-Host 'La zona, el firewall y el FTP se reajustan solos a esta red en menos de un minuto (lab5-red-auto). Siguiente: puente.ps1 verificar'
        } else {
            Write-Warning 'La VM no obtuvo IP en la red. Revise: Wi-Fi conectado, que la red entregue DHCP y el adaptador del puente (README, seccion "Si algo falla").'
        }
    }
    'estado' {
        & $VBox showvminfo $VM --machinereadable | Select-String '^VMState='
        if (Test-Running) {
            Invoke-Remote "ip -4 -br addr; systemctl is-active named slapd apache2 postfix@- dovecot vsftpd"
        }
    }
    'ip' { Invoke-Remote "ip -4 -o addr show dev enp0s8 scope global | awk '{print `$4}'" }
    'mac' { Get-Macs | Format-Table -AutoSize }
    'verificar' { Invoke-Remote 'sudo bash /opt/lab5/virtualbox/verificar-red-dns.sh' }
    'ips' {
        $permitidos = '^(ldap|www|mail|ftp)=(vm|(\d{1,3}\.){3}\d{1,3})$|^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$|^--todo-en-la-vm$|^--simular$'
        foreach ($a in $Resto) {
            if ($a -notmatch $permitidos) { throw "Argumento no valido: $a  (use ldap=IP www=IP mail=IP ftp=IP, nombre=vm, IP/prefijo, --todo-en-la-vm o --simular)" }
        }
        Invoke-Remote ('sudo bash /opt/lab5/virtualbox/cambiar-ip.sh ' + ($Resto -join ' '))
    }
    'entregables' {
        $dir = if ($Resto) { $Resto[0] } else { Join-Path $env:USERPROFILE ('lab5-evidencias\entregable-dns-' + (Get-Date -Format 'yyyyMMdd-HHmm')) }
        Invoke-Remote 'sudo bash /opt/lab5/virtualbox/entregables-dns.sh /home/labadmin/entregable-dns'
        Copy-FromVm '~/entregable-dns/.' $dir
        Invoke-Remote 'rm -r /home/labadmin/entregable-dns'
        Write-Host ''
        Write-Host "Entregables de DNS en: $dir" -ForegroundColor Green
        Get-ChildItem -LiteralPath $dir -Recurse -File | ForEach-Object { '  ' + $_.FullName.Substring($dir.Length).TrimStart('\') }
        Write-Host 'La zona (db.aerolinea.redes.test) y resolucion-dns.md son los entregables c y b; las capturas de pantalla las toma una persona.'
    }
    'respaldar' {
        if (-not (Test-Registered)) { throw "No existe la VM $VM." }
        $dejarApagada = [bool]($Resto -contains '--dejar-apagada')
        $carpeta = Join-Path $Priv 'respaldo'
        New-Item -ItemType Directory -Force -Path $carpeta | Out-Null
        $estabaEncendida = Test-Running
        if ($estabaEncendida) {
            Write-Host 'Apagando la VM con el apagado normal (ACPI); los servicios quedan detenidos unos minutos...'
            & $VBox controlvm $VM acpipowerbutton
            if (-not (Wait-VmState 'poweroff' 240)) { throw 'La VM no se apago en 4 minutos. No se fuerza: revise la VM (puente.ps1 estado) y repita.' }
        }
        $ova = Join-Path $carpeta ('{0}-{1}.ova' -f $VM, (Get-Date -Format 'yyyyMMdd-HHmm'))
        Write-Host "Exportando a $ova (de 3 a 10 minutos)..."
        & $VBox export $VM --output $ova --ovf20 --manifest
        if ($LASTEXITCODE) { throw 'La exportacion fallo.' }
        $hash = (Get-FileHash -Algorithm SHA256 -LiteralPath $ova).Hash
        $info = & $VBox showvminfo $VM --machinereadable
        $nota = @(
            "Respaldo de la VM $VM", "Fecha: $(Get-Date -Format 's')", "VirtualBox: $(& $VBox --version)", "SHA256 del .ova: $hash", '',
            'Adaptadores (la MAC del NIC2 es la que se entrega al catedratico):'
        ) + @(Get-Macs | ForEach-Object { '  {0} {1} {2}' -f $_.Adaptador, $_.Modo, $_.MAC }) + @(
            ($info | Select-String '^bridgeadapter2=').Line, ($info | Select-String '^Forwarding\(').Line, '',
            'Restaurar (sin Internet), en esta u otra PC con VirtualBox 7.x:',
            "  powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 importar `"$ova`"",
            '  powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar'
        )
        Set-Content -LiteralPath ($ova + '.txt') -Value $nota -Encoding UTF8
        Write-Host ''
        Write-Host "Respaldo listo: $ova" -ForegroundColor Green
        Write-Host ('Tamano: {0:N1} GB   SHA256: {1}' -f ((Get-Item -LiteralPath $ova).Length / 1GB), $hash)
        Write-Host "Notas: $ova.txt"
        if ($estabaEncendida -and -not $dejarApagada) {
            Write-Host 'Volviendo a encender la VM (tarda de 4 a 6 minutos en dar servicio)...'
            & $VBox startvm $VM --type headless
        } elseif ($estabaEncendida) {
            Write-Host 'La VM quedo apagada (--dejar-apagada). Para encenderla: puente.ps1 iniciar'
        }
    }
    'importar' {
        if (-not $Resto) { throw 'Uso: puente.ps1 importar <respaldo.ova>' }
        $ova = $Resto[0]
        if (-not (Test-Path -LiteralPath $ova)) { throw "No existe el archivo: $ova" }
        if (Test-Registered) { throw "Ya existe una VM llamada $VM en este VirtualBox. Para reemplazarla primero: VBoxManage unregistervm `"$VM`" --delete (borra su disco), o importe con otro nombre usando la variable LAB_VM_NAME." }
        Write-Host "Importando $ova como '$VM' (de 3 a 8 minutos)..."
        & $VBox import $ova --vsys 0 --vmname $VM --options keepallmacs
        if ($LASTEXITCODE) { throw 'La importacion fallo.' }
        # Reenvio local para administrar por SSH (127.0.0.1:<puerto> -> 22 de la VM). El .ova trae el del equipo original:
        # se reemplaza para que coincida con LAB_NAT_SSH_PORT (si no, "puente.ps1 ssh" apuntaria a un puerto sin nadie).
        $info = & $VBox showvminfo $VM --machinereadable
        if ($info | Select-String '^Forwarding\(\d+\)="lab5-ssh,') { & $VBox modifyvm $VM --natpf1 delete lab5-ssh }
        & $VBox modifyvm $VM --natpf1 "lab5-ssh,tcp,127.0.0.1,$SshPort,,22"
        if ($LASTEXITCODE) { Write-Warning "No se pudo crear el reenvio SSH al puerto $SshPort (puede estar usado por otra VM): cambie LAB_NAT_SSH_PORT y repita el modifyvm." }
        # El nombre del adaptador fisico cambia de una PC a otra: se elige uno activo de ESTA PC (LAB_BRIDGE_ADAPTER lo fija).
        $adaptador = $env:LAB_BRIDGE_ADAPTER
        if (-not $adaptador) {
            $primero = Get-BridgeIfs | Where-Object { $_.Estado -eq 'Up' -and $_.IP -ne '0.0.0.0' } | Select-Object -First 1
            if ($primero) { $adaptador = $primero.Nombre }
        }
        if ($adaptador) {
            & $VBox modifyvm $VM --nic2 bridged --bridgeadapter2 $adaptador
            Write-Host "Adaptador en puente: $adaptador"
        } else {
            Write-Warning 'No hay adaptador fisico activo: conecte el Wi-Fi y ajuste el puente con: VBoxManage modifyvm "<VM>" --nic2 bridged --bridgeadapter2 "<nombre de: VBoxManage list bridgedifs>"'
        }
        Write-Host ''
        Write-Host 'VM importada con las mismas MAC. Siguiente:' -ForegroundColor Green
        Write-Host "  1. Las llaves SSH deben estar en $Priv\virtualbox-private (id_rsa, id_rsa.openssh). Si esta es otra PC, copielas del kit."
        Write-Host '  2. powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar'
        Write-Host '  3. powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 verificar'
    }
    'kit' {
        $destino = if ($Resto -and $Resto[0] -notlike '--*') { $Resto[0] } else { Join-Path $env:USERPROFILE 'lab5-kit-laboratorio' }
        $conOva = [bool]($Resto -contains '--con-ova')
        $repo = Split-Path -Parent $PSScriptRoot
        $padre = Split-Path -Parent $repo
        New-Item -ItemType Directory -Force -Path (Join-Path $destino 'guias'), (Join-Path $destino '.lab5-private\virtualbox-private'), (Join-Path $destino '.lab5-private\lab5-private') | Out-Null
        $guias = @(Get-ChildItem -LiteralPath $padre -Filter 'GUIA-*.md' -File -ErrorAction SilentlyContinue)
        $guias | Copy-Item -Destination (Join-Path $destino 'guias') -Force
        $zip = Join-Path $padre 'Lab5-paquete.zip'
        if (-not (Test-Path -LiteralPath $zip)) { python (Join-Path $PSScriptRoot 'crear-paquete.py') --salida $zip }
        Copy-Item -LiteralPath $zip -Destination $destino -Force
        foreach ($f in 'id_rsa', 'id_rsa.openssh', 'id_rsa.pub', 'known_hosts') {
            $origen = Join-Path $Priv "virtualbox-private\$f"
            if (Test-Path -LiteralPath $origen) { Copy-Item -LiteralPath $origen -Destination (Join-Path $destino '.lab5-private\virtualbox-private') -Force }
        }
        $cred = Join-Path $Priv 'lab5-private\credentials.json'
        if (Test-Path -LiteralPath $cred) { Copy-Item -LiteralPath $cred -Destination (Join-Path $destino '.lab5-private\lab5-private') -Force }
        # Paquetes de Python (paramiko) para usar este script en OTRA laptop sin Internet. Si ahora no hay Internet, se omite.
        $ruedas = Join-Path $destino 'wheels'
        New-Item -ItemType Directory -Force -Path $ruedas | Out-Null
        $previo = $ErrorActionPreference; $ErrorActionPreference = 'Continue'
        foreach ($v in '3.11', '3.12', '3.13') {
            & python -m pip download paramiko -d $ruedas --only-binary=:all: --platform win_amd64 --python-version $v --implementation cp --quiet 2>&1 | Out-Null
        }
        $ErrorActionPreference = $previo
        $nRuedas = @(Get-ChildItem -LiteralPath $ruedas -File -ErrorAction SilentlyContinue).Count
        $ultimoOva = Get-ChildItem -LiteralPath (Join-Path $Priv 'respaldo') -Filter '*.ova' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime | Select-Object -Last 1
        $textoOva = 'No hay respaldo .ova todavia: ejecute puente.ps1 respaldar (apaga la VM unos 10 minutos).'
        if ($ultimoOva) {
            if ($conOva) {
                Copy-Item -LiteralPath $ultimoOva.FullName -Destination $destino -Force
                $notaOva = $ultimoOva.FullName + '.txt'
                if (Test-Path -LiteralPath $notaOva) { Copy-Item -LiteralPath $notaOva -Destination $destino -Force }
                $textoOva = 'Respaldo incluido: ' + $ultimoOva.Name
            } else {
                $textoOva = 'Ultimo respaldo (no copiado; agregue --con-ova): ' + $ultimoOva.FullName
            }
        }
        $leame = @(
            'KIT DEL LABORATORIO 5 (parte DNS) - sin Internet', '',
            'guias\                       las guias en Markdown (abrir con VS Code o el Bloc de notas)',
            'Lab5-paquete.zip             scripts y servicios del laboratorio (sin claves)',
            '.lab5-private\               LLAVES SSH y CREDENCIALES de la VM: son secretas, no las suba ni las comparta por grupos',
            '*.ova                        respaldo de la VM (si se incluyo con --con-ova)',
            'wheels\                      paquetes de Python (paramiko) para instalar SIN Internet en otra laptop', '',
            'Restaurar en esta PC o en otra (si la VM se dano o se borro):',
            '  1. Descomprima Lab5-paquete.zip (por ejemplo en C:\lab5) y copie la carpeta .lab5-private a %USERPROFILE%',
            '  2. Solo en otra laptop: python -m pip install --no-index --find-links <este kit>\wheels paramiko',
            '  3. cd C:\lab5\Lab-05-Redes',
            '  4. powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 importar <ruta\al\respaldo.ova>',
            '  5. powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 iniciar',
            '  6. powershell -ExecutionPolicy Bypass -File virtualbox/puente.ps1 verificar', '',
            'Requisitos en otra PC: VirtualBox 7.x y Python 3.11, 3.12 o 3.13 de 64 bits (los instaladores se bajan con Internet, antes de ir).'
        )
        Set-Content -LiteralPath (Join-Path $destino 'LEEME-KIT.txt') -Value $leame -Encoding UTF8
        Write-Host "Kit en: $destino" -ForegroundColor Green
        Write-Host ('  Guias copiadas: {0}   Paquete: {1}   Llaves/credenciales: incluidas' -f $guias.Count, (Split-Path -Leaf $zip))
        if ($nRuedas) { Write-Host "  Paquetes de Python para otra laptop (wheels): $nRuedas archivos" } else { Write-Warning 'No se pudieron bajar los paquetes de Python (wheels): requieren Internet. Repita "kit" cuando tenga conexion si piensa usar otra laptop.' }
        Write-Host "  $textoOva"
        Write-Warning 'El kit contiene la llave SSH y las credenciales de la VM: llevelo en un USB propio y no lo suba a ninguna nube.'
    }
    'ssh' {
        ssh -i $KeyFile -p $SshPort -o "UserKnownHostsFile=$KnownHosts" labadmin@127.0.0.1 @Resto
    }
    'traer' {
        if (-not $Resto) { throw 'Uso: puente.ps1 traer <ruta-en-la-VM> [destino-en-Windows]' }
        $destino = if ($Resto.Count -ge 2) { $Resto[1] } else { Join-Path $env:USERPROFILE 'lab5-evidencias\vm' }
        Copy-FromVm $Resto[0] $destino
        Write-Host "Copiado a $destino"
    }
    'detener' {
        # Apagado normal (ACPI). Espera a que la VM quede en poweroff: asi un "iniciar" inmediato no se encuentra con una VM que todavia se apaga.
        if (-not (Test-Running)) { Write-Host 'La VM ya esta apagada.'; break }
        & $VBox controlvm $VM acpipowerbutton
        if ($LASTEXITCODE) { throw 'No se pudo solicitar el apagado normal.' }
        Write-Host 'Apagando la VM (apagado normal; puede tardar 1 o 2 minutos)...'
        if (Wait-VmState 'poweroff' 240) {
            Write-Host 'VM apagada. Ya puede ejecutar: puente.ps1 iniciar' -ForegroundColor Green
        } else {
            Write-Warning 'Sigue encendida despues de 4 minutos. Revise con: puente.ps1 estado. Si hay que forzarla (se pierde lo que no se haya guardado): VBoxManage controlvm CC3067-Lab5-Ubuntu poweroff'
        }
    }
}
