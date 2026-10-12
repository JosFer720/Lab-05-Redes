$ErrorActionPreference = 'Stop'
$script = Join-Path $PSScriptRoot 'actualizar-red-lan.py'
Get-Content -Raw -Encoding UTF8 $script | python (Join-Path $PSScriptRoot 'ssh-run.py') --command 'sudo python3 -'
if ($LASTEXITCODE) { throw 'No se actualizó la LAN. Revise DHCP, puente y la salida SSH; no use una IP supuesta.' }
