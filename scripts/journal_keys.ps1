param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Journal capture (read-only probe on). Diary: Escape once (opens the days
# menu), Down, back with Tab-close later. Then each other tab: Right/Down to move
# the highlight, Enter to open the entry, Escape back to the list. Never a
# second Escape (that leaves the journal for the pause menu).
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=3){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 6
Press 0x09 'Tab (journal)' 5
Press 0x1B 'Escape (diary -> days menu)' 4
Press 0x28 'Down (days)' 3
Press 0x28 'Down (days)' 3
Press 0x0D 'Enter (open day)' 4
Press 0x45 'E (to characters)' 4
Press 0x27 'Right (characters)' 3
Press 0x0D 'Enter (open character)' 4
Press 0x1B 'Escape (back to characters)' 4
Press 0x45 'E (to photos)' 4
Press 0x27 'Right (photos)' 3
Press 0x0D 'Enter (open photo set)' 4
Press 0x1B 'Escape (back)' 4
Press 0x45 'E (to places)' 4
Press 0x27 'Right (places)' 3
Press 0x0D 'Enter (open place)' 4
Press 0x1B 'Escape (back)' 4
Press 0x45 'E (to messages)' 4
Press 0x28 'Down (messages)' 3
Press 0x0D 'Enter (open thread)' 4
Press 0x1B 'Escape (back)' 4
Press 0x09 'Tab (close the journal)' 4
'Journal capture finished.'
