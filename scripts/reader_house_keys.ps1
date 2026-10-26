param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Reader capture in Chloe's house (read-only probe on). Mail: picked by NAME,
# looked at, Read, page turn, back out. Journal: in each tab, Down + Enter to
# open an entry, then Escape back, before moving to the next tab.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Lines([string]$P){@(Select-String -LiteralPath $LogPath -Pattern $P)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=3){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 6
# Select the mail by name: Page Down until the newest readout is the mail.
$found=$false
foreach($i in 1..12){
    $before=(Lines 'scanner_readout spoken=').Count
    Press 0x22 'Page Down' 2
    $last=Lines 'scanner_readout spoken=' | Select-Object -Last 1
    if($last -and $last.Line -match 'spoken=Mail,'){$found=$true;break}
}
if($found){
    if(-not [LISKeyTest]::PressWithShift($Game.Id,0x24)){throw 'Shift+Home not sent'};Mark 'sent Shift+Home';Start-Sleep -Seconds 6
    Press 0x46 'F' 3
    if((Lines 'focus_announce spoken=Mail\.').Count){
        Press 0x31 '1 (Look at the mail)' 8
        Press 0x0D 'Enter (Read)' 4
        Press 0x27 'Right arrow (next page)' 3
        Press 0x1B 'Escape' 3
        Press 0x1B 'Escape (close)' 5
    } else { Mark 'Mail actions not announced; skipped' }
} else { Mark 'Mail not found in 12 entries; skipped' }
Press 0x09 'Tab (journal)' 5
foreach($i in 1..5){
    Press 0x28 "Down (tab $i)" 2
    Press 0x0D "Enter (tab $i)" 4
    Press 0x1B "Escape (tab $i)" 3
    Press 0x45 "E (to tab $($i+1))" 4
}
Press 0x1B 'Escape (close the journal)' 4
'Reader capture finished.'
