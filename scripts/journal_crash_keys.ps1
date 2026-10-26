param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Reproduces the user's crash by keyboard: journal (Tab), Characters (E), open a
# character (Enter), Down three times, Enter (A) while in the profile.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=2){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 6
Press 0x09 'Tab (journal)' 4
Press 0x45 'E (characters)' 4
Press 0x0D 'Enter (open character)' 4
foreach($i in 1..3){Press 0x28 "Down $i" 1}
Press 0x0D 'Enter (A in profile)' 6
Press 0x09 'Tab (close journal)' 4
'Journal crash repro finished.'
