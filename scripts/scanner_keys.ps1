param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Scanner key test in a test scene: Page Down x4, Page Up x2, Home, Ctrl+Home.
# Read-only (no movement, no activation). Also records Max's position and the
# camera before and after, so any game-side effect of these keys shows up.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds 2
}
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded; no keys sent'};Start-Sleep -Milliseconds 500
}
Start-Sleep -Seconds 4
foreach($i in 1..4){Press 0x22 'Page Down'}
foreach($i in 1..2){Press 0x21 'Page Up'}
Press 0x24 'Home'
if(-not [LISKeyTest]::PressWithControl($Game.Id,0x24)){Mark 'NOT SENT: Ctrl+Home'}else{Mark 'sent Ctrl+Home';Start-Sleep -Seconds 2}
'Scanner key sequence finished.'
