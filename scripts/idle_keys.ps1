param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# No keys: Max stands at the house start beside the front door (in the
# game's reach zone) for 3 minutes while the background polling runs.
$ErrorActionPreference='Stop'
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
$end=(Get-Date).AddSeconds(180)
while((Get-Date)-lt $end){$Game.Refresh();if($Game.HasExited){throw 'Game exited during idle watch'};Start-Sleep -Seconds 1}
'Idle focus watch finished.'

