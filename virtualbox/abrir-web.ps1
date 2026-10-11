$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Edge = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
$Profile = Join-Path $Root '.git\virtualbox-private\edge-profile'
Start-Process -FilePath $Edge -ArgumentList @(('--user-data-dir="' + $Profile + '"'),'--proxy-server=socks5://127.0.0.1:10805','http://www.aerolinea.redes.test') -WindowStyle Normal
