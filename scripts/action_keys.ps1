param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# First interaction test, harmless: select Mail, autowalk to it, face it, then
# press 1 only if the mod announced Mail's actions with "1, Look". Logs what
# happened. Throwaway profile.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Has([string]$P){Select-String -LiteralPath $LogPath -Pattern $P -Quiet}
function Press([uint16]$Key,[string]$Name,[int]$Wait=2){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 6
# Select Mail (third nearest at the start).
foreach($i in 1..3){Press 0x22 'Page Down'}
if(-not (Has 'scanner_readout spoken=Mail,')){Mark 'STOP: Mail not selected';throw 'Mail not selected'}
if(-not [LISKeyTest]::PressWithShift($Game.Id,0x24)){throw 'Shift+Home not sent'};Mark 'sent Shift+Home';Start-Sleep -Seconds 6
Press 0x46 'F' 3
if(Has 'focus_announce spoken=Mail\. 1, Look'){ Press 0x31 '1 (Look)' 8 } else { Mark 'STOP: Mail actions not announced; 1 not pressed' }
'Interaction test finished.'
