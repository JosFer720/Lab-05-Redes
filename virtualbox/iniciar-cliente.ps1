$ErrorActionPreference = 'Stop'
$Root = Split-Path $PSScriptRoot -Parent
$Private = Join-Path $Root '.git\virtualbox-private'
$Python = (Get-Command python.exe -ErrorAction Stop).Source
$ProxyPidFile = Join-Path $Private 'proxy.pid'
$ProxyRunning = $false
if (Test-Path $ProxyPidFile) { $ProxyRunning = [bool](Get-Process -Id (Get-Content $ProxyPidFile) -ErrorAction SilentlyContinue) }
if (!$ProxyRunning) {
  $Proxy = Start-Process -FilePath $Python -ArgumentList @((Join-Path $PSScriptRoot 'proxy-thunderbird.py')) -WorkingDirectory $Root -WindowStyle Hidden -PassThru
  $Proxy.Id | Set-Content $ProxyPidFile
}
$Thunderbird = Join-Path $env:LOCALAPPDATA 'CC3067-Lab5\Thunderbird\thunderbird.exe'
if (!(Test-Path $Thunderbird)) { throw 'Thunderbird del laboratorio ausente. Consulte README.md.' }
$Profile = Join-Path $Private 'thunderbird-profile'
$ClientRunning = Get-CimInstance Win32_Process -Filter "Name='thunderbird.exe'" | Where-Object { $_.CommandLine -like "*$Profile*" }
if (!$ClientRunning) {
  Start-Process -FilePath $Thunderbird -ArgumentList @('-no-remote','-profile',('"' + $Profile + '"'),'--marionette','--remote-allow-system-access') -WindowStyle Normal
  Start-Sleep -Seconds 5
}
& $Python (Join-Path $PSScriptRoot 'configurar-thunderbird.py')
if ($LASTEXITCODE) { throw 'No se pudo configurar el perfil del laboratorio.' }
