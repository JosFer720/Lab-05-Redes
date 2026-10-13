<#
 Cliente Windows del Laboratorio 5. Sirve cuando los servicios corren en OTRA computadora de la red
 (una VM Ubuntu en puente): comprueba que responde, hace que Windows consulte su DNS solo para
 aerolinea.redes.test y ejecuta las pruebas de la matriz. No toca el archivo hosts ni el DNS general.

 Uso (desde la raiz del repositorio, en PowerShell):
   powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 estado  -Servidor 192.168.1.50
   powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 dns-on  -Servidor 192.168.1.50    (como administrador)
   powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 dns-off                            (como administrador)
   powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 pruebas -Servidor 192.168.1.50 -Credenciales C:\ruta\credentials.json
   powershell -ExecutionPolicy Bypass -File client/windows/cliente.ps1 ldap    -Servidor 192.168.1.50 -Credenciales C:\ruta\credentials.json

 Parametros:
   -Servidor       IP de la VM que corre los servicios (tambien se toma de la variable LAB_DNS_SERVER).
   -Credenciales   credentials.json del servidor que se prueba. Si se omite se busca en LAB_CREDENTIALS,
                   %LAB5_PRIVATE_DIR%\lab5-private\ y %USERPROFILE%\.lab5-private\lab5-private\.
   -Salida         JSON de resultados (predeterminado: %USERPROFILE%\lab5-evidencias\resultados-<IP>-<fecha>.json).
   -Usuario        uid LDAP para las pruebas del subcomando ldap (predeterminado: icumes).
#>
param(
    [Parameter(Position = 0)][ValidateSet('estado', 'dns-on', 'dns-off', 'pruebas', 'ldap')][string]$Accion = 'estado',
    [string]$Servidor = $env:LAB_DNS_SERVER,
    [string]$Credenciales,
    [string]$Salida,
    [string]$Usuario = 'icumes'
)
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
$Dominio = 'aerolinea.redes.test'
$Marca = 'Lab5-aerolinea'
$Repo = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path

function Exigir-Servidor {
    if (-not $Servidor -or $Servidor -notmatch '^(\d{1,3}\.){3}\d{1,3}$') {
        throw 'Indique la IP del servidor del laboratorio, por ejemplo: -Servidor 192.168.1.50'
    }
}
function Exigir-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    if (-not ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        throw 'Esta accion cambia la configuracion DNS de Windows: abra PowerShell con "Ejecutar como administrador" y repita el comando.'
    }
}
function Test-Tcp([string]$Ip, [int]$Puerto, [int]$Ms = 3000) {
    $c = New-Object System.Net.Sockets.TcpClient
    try { return ($c.ConnectAsync($Ip, $Puerto).Wait($Ms) -and $c.Connected) } catch { return $false } finally { $c.Close() }
}
function ConvertTo-Long([string]$Ip) {
    $b = [System.Net.IPAddress]::Parse($Ip).GetAddressBytes()
    return ([int64]$b[0] * 16777216) + ([int64]$b[1] * 65536) + ([int64]$b[2] * 256) + [int64]$b[3]
}
function Resolver-Credenciales {
    # Una ruta indicada a mano (-Credenciales o LAB_CREDENTIALS) debe existir: nunca se sustituye en silencio por otra.
    $explicita = if ($Credenciales) { $Credenciales } else { $env:LAB_CREDENTIALS }
    if ($explicita) {
        if (Test-Path -LiteralPath $explicita) { return (Resolve-Path -LiteralPath $explicita).Path }
        throw "No existe el archivo de credenciales indicado: $explicita"
    }
    $candidatos = @()
    if ($env:LAB5_PRIVATE_DIR) { $candidatos += (Join-Path $env:LAB5_PRIVATE_DIR 'lab5-private\credentials.json') }
    $candidatos += (Join-Path $env:USERPROFILE '.lab5-private\lab5-private\credentials.json')
    foreach ($c in $candidatos) { if ($c -and (Test-Path -LiteralPath $c)) { return (Resolve-Path -LiteralPath $c).Path } }
    throw ('No encuentro credentials.json. Pida a quien administra el servidor su archivo y use -Credenciales <ruta>. Busque en: ' + ($candidatos -join '; '))
}

switch ($Accion) {
    'estado' {
        Exigir-Servidor
        Write-Host "== Laboratorio 5: comprobacion del servidor $Servidor ==" -ForegroundColor Cyan
        $cfg = Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1
        if ($cfg) {
            $mia = $cfg.IPv4Address.IPAddress; $pref = $cfg.IPv4Address.PrefixLength
            $mask = ([int64]4294967295 -shl (32 - $pref)) -band 4294967295
            $mismaRed = ((ConvertTo-Long $mia) -band $mask) -eq ((ConvertTo-Long $Servidor) -band $mask)
            Write-Host ("Tu PC:        {0}/{1} por {2}, puerta de enlace {3}" -f $mia, $pref, $cfg.InterfaceAlias, $cfg.IPv4DefaultGateway.NextHop)
            Write-Host ("Misma red:    " + $(if ($mismaRed) { 'SI' } else { 'NO - el servidor no esta en tu segmento; revisa que ambos usen el mismo Wi-Fi' }))
        }
        $ping = Test-Connection -ComputerName $Servidor -Count 2 -ErrorAction SilentlyContinue
        if ($ping) { Write-Host ("Ping:         OK ({0} ms)" -f [int](($ping | Measure-Object ResponseTime -Average).Average)) }
        else { Write-Host 'Ping:         sin respuesta (puede estar filtrado; se sigue con los puertos)' -ForegroundColor Yellow }
        $arp = (arp -a $Servidor 2>$null) | Select-String -Pattern ([regex]::Escape($Servidor) + '\s+([0-9a-f-]{17})') | Select-Object -First 1
        if ($arp) { Write-Host ("ARP:          {0} (desde otra PC por Wi-Fi puede salir la MAC de la tarjeta de la PC que aloja la VM)" -f $arp.Matches[0].Groups[1].Value) }
        $fallas = 0
        try {
            $r = Resolve-DnsName -Name "ns1.$Dominio" -Server $Servidor -Type A -DnsOnly -QuickTimeout -ErrorAction Stop
            Write-Host ("DNS 53/udp:   OK  ns1.{0} -> {1}" -f $Dominio, ($r | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1).IPAddress)
        } catch { Write-Host 'DNS 53/udp:   FALLA (BIND no responde por UDP)' -ForegroundColor Red; $fallas++ }
        $puertos = [ordered]@{ 'DNS 53/tcp' = 53; 'HTTP 80' = 80; 'LDAP 389' = 389; 'SMTP 25' = 25; 'Submission 587' = 587; 'IMAP 143' = 143; 'FTP 21' = 21 }
        foreach ($k in $puertos.Keys) {
            if (Test-Tcp $Servidor $puertos[$k]) { Write-Host ('{0,-13} OK' -f ($k + ':')) }
            else { Write-Host ('{0,-13} FALLA' -f ($k + ':')) -ForegroundColor Red; $fallas++ }
        }
        if ($fallas -eq 0) { Write-Host "`nTodo responde. Siguiente paso: dns-on (como administrador) y luego pruebas." -ForegroundColor Green }
        else {
            Write-Host "`nHay $fallas comprobaciones con falla. Causas habituales, en este orden:" -ForegroundColor Yellow
            Write-Host '  1. La IP del servidor cambio (otra red o DHCP): pide la IP actual a quien lo aloja.'
            Write-Host '  2. Las dos PCs no estan en la misma red, o el Wi-Fi aisla a los clientes (red de invitados): usen el hotspot de un celular.'
            Write-Host '  3. La VM esta apagada, suspendida o sin los servicios activos.'
            Write-Host '  4. El firewall de la VM solo admite la red donde se instalo: si cambio de red, debe correr cambiar-ip.sh.'
            exit 1
        }
    }
    'dns-on' {
        Exigir-Servidor; Exigir-Admin
        Get-DnsClientNrptRule | Where-Object { $_.Comment -eq $Marca } | ForEach-Object { Remove-DnsClientNrptRule -Name $_.Name -Force }
        Add-DnsClientNrptRule -Namespace ".$Dominio" -NameServers $Servidor -Comment $Marca | Out-Null
        Clear-DnsClientCache
        Write-Host "Regla creada: los nombres *.$Dominio se consultan a $Servidor (el resto de Internet sigue igual)." -ForegroundColor Green
        $r = Resolve-DnsName -Name "www.$Dominio" -Type A -DnsOnly -ErrorAction Stop
        Write-Host ("Comprobacion sin indicar servidor: www.{0} -> {1}" -f $Dominio, ($r | Where-Object { $_.Type -eq 'A' } | Select-Object -First 1).IPAddress)
        Write-Host 'Para quitarla al terminar: client/windows/cliente.ps1 dns-off (como administrador).'
    }
    'dns-off' {
        Exigir-Admin
        $reglas = @(Get-DnsClientNrptRule | Where-Object { $_.Comment -eq $Marca })
        $reglas | ForEach-Object { Remove-DnsClientNrptRule -Name $_.Name -Force }
        Clear-DnsClientCache
        Write-Host ("Reglas del laboratorio eliminadas: {0}. Windows vuelve a usar su DNS normal." -f $reglas.Count) -ForegroundColor Green
    }
    'pruebas' {
        Exigir-Servidor
        $cred = Resolver-Credenciales
        if (-not $Salida) {
            $dir = Join-Path $env:USERPROFILE 'lab5-evidencias'
            New-Item -ItemType Directory -Force -Path $dir | Out-Null
            $Salida = Join-Path $dir ("resultados-{0}-{1}.json" -f $Servidor, (Get-Date -Format 'yyyyMMdd-HHmm'))
        }
        Write-Host "Servidor probado: $Servidor" -ForegroundColor Cyan
        Write-Host "Credenciales:     $cred   (deben ser las del servidor que pruebas)"
        Write-Host "Resultados:       $Salida`n"
        $env:LAB_DNS_SERVER = $Servidor; $env:LAB_CREDENTIALS = $cred; $env:LAB_RESULTS = $Salida
        & python (Join-Path $Repo 'virtualbox\pruebas-windows.py')
        $codigo = $LASTEXITCODE
        if (Test-Path -LiteralPath $Salida) {
            Write-Host ''
            # En Windows PowerShell 5.1 ConvertFrom-Json entrega el arreglo como un solo objeto: se guarda antes de canalizar.
            $filas = ConvertFrom-Json -InputObject (Get-Content -Raw -Encoding UTF8 -LiteralPath $Salida)
            $filas | Select-Object id, status, @{ n = 'observado'; e = { $t = ($_.observed -replace '\s+', ' '); $t.Substring(0, [math]::Min(72, $t.Length)) } } |
                Format-Table -AutoSize
        }
        exit $codigo
    }
    'ldap' {
        Exigir-Servidor
        $cred = Resolver-Credenciales
        & python (Join-Path $PSScriptRoot 'ldap-evidencia.py') --server $Servidor --credentials $cred --user $Usuario
        exit $LASTEXITCODE
    }
}
