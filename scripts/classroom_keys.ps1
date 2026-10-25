param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Classroom facing test: once Max is playable, select each of the first five
# scanner entries (Camera, Journal, Bag, ...) with Page Down and press F, with
# time for the correction loop and the focused-object announcement. No actions.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=2){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(150)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Classroom loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
# Wait for control (the "back" control event), up to two minutes.
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISAccess] control back" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){Mark 'control never came back; trying anyway';break};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 2
# Photo first (it gates the rest), then the camera and the journal.
Press 0x22 'Page Down' 2;Press 0x22 'Page Down' 2;Press 0x22 'Page Down' 2;Press 0x22 'Page Down' 2;Press 0x46 'F (Photo)' 5
Press 0x31 '1 (Look at photo)' 12
Press 0x21 'Page Up' 2;Press 0x21 'Page Up' 2;Press 0x21 'Page Up' 2;Press 0x46 'F (Camera)' 5
Press 0x22 'Page Down' 2;Press 0x46 'F (Journal)' 5
'Classroom face test finished.'
