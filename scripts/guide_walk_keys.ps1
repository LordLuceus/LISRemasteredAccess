param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Ending nightmare: select the guide (Page Down) and start it (Shift+Home);
# the guide chains steps by itself. Watch for 150 s. Hazards will kill Max -
# that is expected in a test with no rewinding; the log shows how far it got.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
$end=(Get-Date).AddSeconds(180)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 2
# Select the guide by name (other presses may already have moved the selection).
$found=$false
for($i=0;$i -lt 6 -and -not $found;$i++){
    [void][LISKeyTest]::Press($Game.Id,0x22);Start-Sleep -Milliseconds 900
    $last=(Select-String -LiteralPath $LogPath -Pattern 'scanner_readout spoken=' | Select-Object -Last 1).Line
    if($last -match 'spoken=Guide'){$found=$true}
}
Mark "guide selected=$found";if(-not $found){throw 'Guide not selected'}
[void][LISKeyTest]::PressWithShift($Game.Id,0x24);Mark 'Shift+Home'
# Each time the guide reports Max caught: hold R (rewind) for 4 s, wait for the
# "Rewound" line, then start the guide again. Stop after 6 rewinds or 170 s.
$deadline=(Get-Date).AddSeconds(170);$rewinds=0
function Count([string]$P){@(Select-String -LiteralPath $LogPath -Pattern $P).Count}
$caught=Count 'guide_caught';$stopped=Count 'leg_end result=(stalled|timeout|observation_error)|No route to'
while((Get-Date) -lt $deadline -and $rewinds -lt 6){
    $Game.Refresh();if($Game.HasExited){break}
    if((Count 'guide_caught') -gt $caught){
        $caught=Count 'guide_caught';$rewinds++
        Start-Sleep -Milliseconds 800
        [void][LISKeyTest]::Hold($Game.Id,0x52,4000);Mark "held R ($rewinds)"
        $t=(Get-Date).AddSeconds(8);while(-not ((Count 'guide_rewound') -ge $rewinds) -and (Get-Date) -lt $t){Start-Sleep -Milliseconds 300}
        Mark "rewound=$((Count 'guide_rewound') -ge $rewinds)"
        Start-Sleep -Seconds 1
        [void][LISKeyTest]::PressWithShift($Game.Id,0x24);Mark 'Shift+Home again'
        $stopped=Count 'leg_end result=(stalled|timeout|observation_error)|No route to'
    } elseif((Count 'leg_end result=(stalled|timeout|observation_error)|No route to') -gt $stopped -and (Count 'guide_caught') -eq $caught){
        Start-Sleep -Seconds 1
        if((Count 'guide_caught') -eq $caught){Mark 'stopped without being caught';break}
    }
    Start-Sleep -Milliseconds 300
}
Mark "finished rewinds=$rewinds"
'Guide walk finished.'
