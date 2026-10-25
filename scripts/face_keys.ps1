param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Facing, help and preview test in the house: F1, F2 twice, then for the first
# three scanner entries Page Down followed by F. Read-only apart from the
# camera turn. Throwaway profile.
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
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded; no keys sent'};Start-Sleep -Milliseconds 500
}
Start-Sleep -Seconds 6
Press 0x70 'F1' 6
Press 0x71 'F2' 3
Press 0x71 'F2' 3
foreach($i in 1..3){ Press 0x22 'Page Down'; Press 0x46 'F' 3 }
'Face test finished.'
