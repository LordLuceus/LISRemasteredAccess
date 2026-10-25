param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath,[string]$Scene='nightmare')
# Autowalk test with the player-facing keys: once the scene is playable, Page
# Down selects the first scanner entry, then Shift+Home walks to it. In the
# nightmare that entry is the Lighthouse; in the house, the nearest object.
# Then it waits for the walk to end. Throwaway profile.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Has([string]$Text){Select-String -LiteralPath $LogPath -SimpleMatch $Text -Quiet}
$loaded=if($Scene -eq 'nightmare'){"[LISNavSay] Opening nightmare loaded"}else{"[LISNavSay] Chloe's house loaded"}
$end=(Get-Date).AddSeconds(150)
while(-not (Has $loaded)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded; no keys sent'};Start-Sleep -Milliseconds 500}
# Wait until the opening cinematic releases Max: Page Down until a readout appears
# and Shift+Home until a walk starts (refusals say "can't walk right now").
$end=(Get-Date).AddSeconds(150)
while((Get-Date)-lt $end){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,0x22)){Mark 'NOT SENT: Page Down';throw 'Game not foreground'}
    Mark 'sent Page Down';Start-Sleep -Seconds 1
    if(-not [LISKeyTest]::PressWithShift($Game.Id,0x24)){Mark 'NOT SENT: Shift+Home';throw 'Game not foreground'}
    Mark 'sent Shift+Home';Start-Sleep -Seconds 2
    if(Has 'autowalk start target='){break}
    Start-Sleep -Seconds 3
}
if(-not (Has 'autowalk start target=')){Mark 'STOP: walk never started';throw 'Walk never started'}
# Let the walk run to its end (arrival, hand-over or stop), up to two minutes.
$end=(Get-Date).AddSeconds(130)
while((Get-Date)-lt $end -and -not (Has 'autowalk leg_end result=') ){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};Start-Sleep -Seconds 1}
$end=(Get-Date).AddSeconds(130)
while((Get-Date)-lt $end){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    $last=(Select-String -LiteralPath $LogPath -Pattern '\[LISNavSay\] (Arrived|Walking stopped|No route)' | Select-Object -Last 1)
    if($last){break};Start-Sleep -Seconds 1
}
'Autowalk test finished.'
