<#
 Expone ns1 (BIND dentro de WSL2) a la red local para que las VMs de tus
 companeros puedan usarlo como DNS. Ejecutar en PowerShell como ADMINISTRADOR.

 Hace tres cosas, todas reversibles con lan-off.ps1:
   1. Reglas de entrada para 53/UDP y 53/TCP en el firewall de Hyper-V (el que
      filtra a WSL) y en el firewall de Windows, solo desde redes privadas
      (10/8, 172.16/12, 192.168/16 y 100.64/10). Nombres: Lab5-DNS-*.
   2. Activa networkingMode=mirrored en %USERPROFILE%\.wslconfig. En ese modo
      WSL comparte la IP de Windows y la red local alcanza lo que escucha dentro.
      Se guarda un respaldo en .wslconfig.lab5.bak (o un marcador .lab5.none).
   3. Ejecuta "wsl --shutdown": cierra TODAS las distros de WSL, tambien la de
      Docker Desktop. Guarde su trabajo antes.

 Uso:
   .\lan-on.ps1 -DryRun    solo muestra lo que haria, sin cambiar nada
   .\lan-on.ps1            pide confirmacion y aplica
   .\lan-on.ps1 -Yes       aplica sin preguntar
#>
param([switch]$DryRun, [switch]$Yes)

$ErrorActionPreference = 'Stop'
$Creator = '{40E0AC32-46A5-438A-A0B2-2B479E8F2E90}'   # VMCreatorId de WSL (documentacion de Microsoft)
$Private = @('10.0.0.0/8', '172.16.0.0/12', '192.168.0.0/16', '100.64.0.0/10')
$Protocols = @('UDP', 'TCP')
$Cfg = Join-Path $env:USERPROFILE '.wslconfig'
$Bak = "$Cfg.lab5.bak"
$None = "$Cfg.lab5.none"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun) {
    Write-Host 'Falta permiso: abra PowerShell como administrador (clic derecho en el icono > Ejecutar como administrador) y vuelva a correr este script.' -ForegroundColor Red
    exit 1
}

function Step {
    param([string]$Text, [scriptblock]$Action)
    Write-Host ('-> ' + $Text)
    if (-not $DryRun) { & $Action }
}

Write-Host ''
if ($DryRun) { Write-Host '*** SIMULACRO: no se cambia nada ***' -ForegroundColor Yellow }
Write-Host 'Esto va a cerrar TODAS las distros de WSL (incluida Docker Desktop) y abrir el puerto 53 a redes privadas.'
if (-not $DryRun -and -not $Yes) {
    $answer = Read-Host 'Escriba SI para continuar'
    if ($answer -ne 'SI') { Write-Host 'Cancelado.'; exit 0 }
}

foreach ($proto in $Protocols) {
    $name = "Lab5-DNS-$proto" + '53'
    $display = "Lab5 DNS $proto 53 (ns1 en WSL)"
    Step "Firewall de Windows: permitir entrada $proto/53 desde redes privadas ($name)" {
        Remove-NetFirewallRule -Name $name -ErrorAction SilentlyContinue
        New-NetFirewallRule -Name $name -DisplayName $display -Direction Inbound -Action Allow `
            -Protocol $proto -LocalPort 53 -RemoteAddress $Private -Profile Any | Out-Null
    }
    Step "Firewall de Hyper-V (WSL): permitir entrada $proto/53 desde redes privadas ($name-HV)" {
        Remove-NetFirewallHyperVRule -Name "$name-HV" -ErrorAction SilentlyContinue
        New-NetFirewallHyperVRule -Name "$name-HV" -DisplayName $display -Direction Inbound `
            -VMCreatorId $Creator -Protocol $proto -LocalPorts 53 -RemoteAddresses $Private | Out-Null
    }
}

Step "Activar networkingMode=mirrored en $Cfg" {
    if (-not (Test-Path $Bak) -and -not (Test-Path $None)) {
        if (Test-Path $Cfg) {
            Copy-Item -LiteralPath $Cfg -Destination $Bak
        } else {
            New-Item -ItemType File -Path $None | Out-Null
        }
    }
    $lines = New-Object 'System.Collections.Generic.List[string]'
    if (Test-Path $Cfg) { Get-Content $Cfg | ForEach-Object { $lines.Add($_) } }
    $mode = -1
    $section = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\s*networkingMode\s*=') { $mode = $i }
        if ($lines[$i] -match '^\s*\[wsl2\]\s*$') { $section = $i }
    }
    if ($mode -ge 0) {
        $lines[$mode] = 'networkingMode=mirrored'
    } elseif ($section -ge 0) {
        $lines.Insert($section + 1, 'networkingMode=mirrored')
    } else {
        if ($lines.Count -gt 0) { $lines.Add('') }
        $lines.Add('[wsl2]')
        $lines.Add('networkingMode=mirrored')
    }
    [System.IO.File]::WriteAllLines($Cfg, $lines, (New-Object System.Text.UTF8Encoding($false)))
}

Step 'Reiniciar WSL (wsl --shutdown)' { wsl.exe --shutdown }

Write-Host ''
Write-Host 'Listo. Siguientes pasos:' -ForegroundColor Green
Write-Host '  1. .\iniciar-ns1.ps1                   (levanta ns1 y muestra la IP que deben usar tus companeros)'
Write-Host '  2. Desde la VM de un companero:        dig @<tu IP> ns1.aerolinea.redes.test +short'
Write-Host '  3. Si algo falla y quieres volver atras: .\lan-off.ps1'
