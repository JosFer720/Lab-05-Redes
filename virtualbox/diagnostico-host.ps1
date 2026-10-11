param([string]$OutputDirectory = "$PSScriptRoot/../docs/evidencias/red")
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
function Save-Result($Name, [scriptblock]$Action) {
    $path = Join-Path $OutputDirectory $Name
    "Fecha: $([DateTimeOffset]::Now.ToString('o'))`nEquipo: $env:COMPUTERNAME" | Out-File $path -Encoding utf8
    & $Action 2>&1 | Out-String -Width 240 | Out-File $path -Append -Encoding utf8
}
Save-Result 'inventario-host.txt' {
    Get-ComputerInfo | Select-Object WindowsProductName,WindowsVersion,OsName,OsVersion,OsArchitecture,HyperVisorPresent,CsTotalPhysicalMemory
    Get-CimInstance Win32_OperatingSystem | Select-Object Caption,TotalVisibleMemorySize,FreePhysicalMemory
    Get-CimInstance Win32_Processor | Select-Object Name,NumberOfCores,NumberOfLogicalProcessors,VirtualizationFirmwareEnabled,VMMonitorModeExtensions
    Get-PSDrive -PSProvider FileSystem | Select-Object Name,Used,Free
    foreach ($feature in 'Microsoft-Hyper-V-All','VirtualMachinePlatform','Microsoft-Windows-Subsystem-Linux') {
        Get-WindowsOptionalFeature -Online -FeatureName $feature
    }
    wsl --list --verbose
    docker version
    Get-NetAdapter | Select-Object Name,Status,MacAddress,InterfaceDescription,ifIndex
    Get-NetIPConfiguration
    ipconfig /all
}
Save-Result 'rutas.txt' { Get-NetRoute | Sort-Object InterfaceIndex,DestinationPrefix; arp -a }
Save-Result 'dns-cliente.txt' { Get-DnsClientServerAddress }
$vbox = (Get-Command VBoxManage.exe -ErrorAction SilentlyContinue).Source
if (-not $vbox) {
    $candidate = Join-Path $env:ProgramFiles 'Oracle/VirtualBox/VBoxManage.exe'
    if (Test-Path -LiteralPath $candidate) { $vbox = $candidate }
}
Save-Result 'virtualbox-info.txt' {
    if (-not $vbox) { 'BLOCKED: VBoxManage no encontrado'; return }
    & $vbox --version
    foreach ($kind in 'vms','runningvms','hostonlyifs','bridgedifs','dhcpservers','systemproperties','extpacks','natnets') {
        "VBoxManage list $kind"
        & $vbox list $kind
    }
    $vms = & $vbox list vms
    foreach ($vm in $vms) {
        if ($vm -match '\{([0-9a-f-]+)\}$') { & $vbox showvminfo $Matches[1] --machinereadable }
    }
}
