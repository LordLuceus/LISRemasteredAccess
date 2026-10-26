param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Reproduces the user's crash: Main Campus, once control returns press Page Down
# once (first scanner entry), then Shift+Home (autowalk). Breadcrumbs on.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
$end=(Get-Date).AddSeconds(180)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 2
if(-not [LISKeyTest]::Press($Game.Id,0x22)){throw 'Page Down not sent'};Mark 'sent Page Down';Start-Sleep -Seconds 3
if(-not [LISKeyTest]::PressWithShift($Game.Id,0x24)){throw 'Shift+Home not sent'};Mark 'sent Shift+Home';Start-Sleep -Seconds 20
'Campus walk finished.'
