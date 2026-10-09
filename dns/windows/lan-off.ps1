<#
 Deshace lo que hizo lan-on.ps1: quita las reglas de firewall Lab5-DNS-*,
 restaura el .wslconfig original y reinicia WSL. Ejecutar como ADMINISTRADOR.

 Uso:
   .\lan-off.ps1 -DryRun    solo muestra lo que haria
   .\lan-off.ps1            pide confirmacion y aplica
   .\lan-off.ps1 -Yes       aplica sin preguntar

 Las reglas se borran siempre por nombre; nunca se llama a Remove-NetFirewallHyperVRule
 sin -Name, porque eso borraria TODAS las reglas de Hyper-V del equipo.
#>
param([switch]$DryRun, [switch]$Yes)

$ErrorActionPreference = 'Stop'
$Protocols = @('UDP', 'TCP')
$Cfg = Join-Path $env:USERPROFILE '.wslconfig'
$Bak = "$Cfg.lab5.bak"
$None = "$Cfg.lab5.none"

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin -and -not $DryRun) {
    Write-Host 'Falta permiso: abra PowerShell como administrador y vuelva a correr este script.' -ForegroundColor Red
    exit 1
}

function Step {
    param([string]$Text, [scriptblock]$Action)
    Write-Host ('-> ' + $Text)
    if (-not $DryRun) { & $Action }
}

Write-Host ''
if ($DryRun) { Write-Host '*** SIMULACRO: no se cambia nada ***' -ForegroundColor Yellow }
Write-Host 'Esto va a cerrar TODAS las distros de WSL (incluida Docker Desktop) y quitar las reglas Lab5-DNS-*.'
if (-not $DryRun -and -not $Yes) {
    $answer = Read-Host 'Escriba SI para continuar'
    if ($answer -ne 'SI') { Write-Host 'Cancelado.'; exit 0 }
}

foreach ($proto in $Protocols) {
    $name = "Lab5-DNS-$proto" + '53'
    Step "Quitar regla del firewall de Windows $name" { Remove-NetFirewallRule -Name $name -ErrorAction SilentlyContinue }
    Step "Quitar regla del firewall de Hyper-V $name-HV" { Remove-NetFirewallHyperVRule -Name "$name-HV" -ErrorAction SilentlyContinue }
}

Step "Restaurar $Cfg" {
    if (Test-Path $Bak) {
        Copy-Item $Bak $Cfg -Force
        Remove-Item $Bak -Force
    } elseif (Test-Path $None) {
        Remove-Item $Cfg -Force -ErrorAction SilentlyContinue
        Remove-Item $None -Force
    } elseif (Test-Path $Cfg) {
        $lines = @(Get-Content $Cfg | Where-Object { $_ -notmatch '^\s*networkingMode\s*=\s*mirrored' })
        [System.IO.File]::WriteAllLines($Cfg, $lines, (New-Object System.Text.UTF8Encoding($false)))
    }
}

Step 'Reiniciar WSL (wsl --shutdown)' { wsl.exe --shutdown }

Write-Host ''
Write-Host 'Listo: ns1 vuelve al modo NAT (solo esta PC lo alcanza). Para levantarlo: .\iniciar-ns1.ps1' -ForegroundColor Green
