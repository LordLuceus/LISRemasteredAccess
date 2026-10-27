param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Dormitories: select a named scanner entry with Page Down (up to 25 presses,
# reading the scanner readout from the log), then Shift+Home, then wait for the
# walk to end. Targets in order; each walk starts from wherever the last ended.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Lines([string]$P){@(Select-String -LiteralPath $LogPath -Pattern $P)}
$end=(Get-Date).AddSeconds(180)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 3
foreach($target in 'Water Pump'){
    $found=$false
    for($i=0;$i -lt 25 -and -not $found;$i++){
        $n=(Lines 'scanner_readout spoken=').Count
        if(-not [LISKeyTest]::Press($Game.Id,0x22)){throw 'Page Down not sent'}
        $t=(Get-Date).AddSeconds(3); while((Lines 'scanner_readout spoken=').Count -le $n -and (Get-Date) -lt $t){Start-Sleep -Milliseconds 150}
        $last=(Lines 'scanner_readout spoken=' | Select-Object -Last 1).Line
        if($last -match "spoken=$([regex]::Escape($target)),"){$found=$true}
    }
    if(-not $found){Mark "FAIL could not select $target";continue}
    Mark "selected $target"
    $n=(Lines 'autowalk (leg_end|refused)|No route to|You can.t walk').Count
    if(-not [LISKeyTest]::PressWithShift($Game.Id,0x24)){throw 'Shift+Home not sent'};Mark "sent Shift+Home ($target)"
    $t=(Get-Date).AddSeconds(110); while((Lines 'autowalk (leg_end|refused)|No route to|You can.t walk').Count -le $n -and (Get-Date) -lt $t){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};Start-Sleep -Milliseconds 300}
    $res=(Lines 'autowalk leg_end|No route to|Arrived at|Walking stopped' | Select-Object -Last 1).Line -replace '^.*\] ',''
    Mark "result $target : $res"
    Start-Sleep -Seconds 3
}
'Pump walk finished.'
