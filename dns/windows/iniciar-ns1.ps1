<#
 Inicia la distro lab5-ns1 (servidor DNS BIND9 sobre WSL2) y la mantiene viva en
 segundo plano. WSL apaga una distro cuando no tiene ninguna sesion abierta; un
 proceso "sleep infinity" oculto evita que named se detenga.

 Uso:
   .\iniciar-ns1.ps1             iniciar y mostrar el estado
   .\iniciar-ns1.ps1 -Detener    detener la distro (ns1 deja de responder)

 No requiere administrador.
#>
param([switch]$Detener)

$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Distro = 'lab5-ns1'

function Get-KeepAlive {
    Get-CimInstance Win32_Process -Filter "Name = 'wsl.exe'" |
        Where-Object { $_.CommandLine -match $Distro -and $_.CommandLine -match 'sleep' -and $_.CommandLine -match 'infinity' }
}

function Invoke-Ns1 {
    param([string]$Command)
    wsl.exe -d $Distro -u root -- bash -c $Command 2>&1 | ForEach-Object { $_ -replace "`0", '' }
}

if ($Detener) {
    Get-KeepAlive | ForEach-Object { Stop-Process -Id $_.ProcessId -Force }
    wsl.exe --terminate $Distro
    Write-Host 'ns1 detenido.'
    return
}

if (-not (Get-KeepAlive)) {
    Start-Process -FilePath wsl.exe -ArgumentList @('-d', $Distro, '-u', 'root', '--exec', 'sleep', 'infinity') -WindowStyle Hidden
}

$state = ''
for ($i = 0; $i -lt 30; $i++) {
    $state = (Invoke-Ns1 'systemctl is-active named' | Where-Object { $_ } | Select-Object -Last 1)
    if ($state -eq 'active') { break }
    Start-Sleep -Seconds 1
}
if ($state -ne 'active') {
    Write-Warning "named no esta activo (estado: $state). Revise con: wsl -d $Distro -u root -- journalctl -u named -n 30"
    exit 1
}

$cfg = Join-Path $env:USERPROFILE '.wslconfig'
$mirrored = (Test-Path $cfg) -and ((Get-Content $cfg -Raw) -match '(?im)^\s*networkingMode\s*=\s*mirrored')
$wifi = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway -and $_.NetAdapter.Status -eq 'Up' } | Select-Object -First 1
$wifiIp = if ($wifi) { $wifi.IPv4Address.IPAddress } else { '(sin red)' }
$wslIps = (Invoke-Ns1 'hostname -I' | Select-Object -Last 1)

Write-Host ''
Write-Host 'ns1 (BIND9) esta corriendo.' -ForegroundColor Green
Write-Host ('  IP de Windows en la red : {0}' -f $wifiIp)
Write-Host ('  IP(s) que ve la distro  : {0}' -f $wslIps)
if ($mirrored) {
    Write-Host '  Modo de red WSL         : mirrored (la red local puede alcanzar ns1)'
    Write-Host ('  --> DNS que deben usar tus companeros: {0}' -f $wifiIp) -ForegroundColor Yellow
} else {
    Write-Host '  Modo de red WSL         : NAT (SOLO esta PC alcanza ns1)'
    Write-Host '  --> Para que tus companeros lo alcancen: ejecuta lan-on.ps1 como administrador.' -ForegroundColor Yellow
}
Write-Host ''
Write-Host 'Prueba rapida desde dentro de ns1:'
Invoke-Ns1 'dig +short ns1.aerolinea.redes.test; dig +short mail.aerolinea.redes.test'
Write-Host ''
Write-Host "Consola de ns1:  wsl -d $Distro      (repo en ~/lab5)"
