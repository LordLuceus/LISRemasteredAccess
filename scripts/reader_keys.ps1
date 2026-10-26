param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Reader capture (read-only probe on): look at the photo (picture viewer, one page), close
# it, then open the journal with Tab, switch tabs with E twice, and close it.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=3){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(150)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 3
Press 0x31 '1 (Look at the photo)' 8
Press 0x1B 'Escape (close the photo)' 5
Press 0x09 'Tab (journal)' 5
Press 0x45 'E (next tab)' 4
Press 0x45 'E (next tab)' 4
Press 0x1B 'Escape (close the journal)' 4
'Reader capture finished.'
