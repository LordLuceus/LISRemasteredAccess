param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Story-gate capture: once control returns, press Page Down once so the scanner
# reads every registered object (the gate trace logs each one's flags). No
# actions, no movement.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
$end=(Get-Date).AddSeconds(150)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned; no keys sent'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 3
$Game.Refresh();if($Game.HasExited){throw 'Game exited'}
if(-not [LISKeyTest]::Press($Game.Id,0x22)){Mark 'NOT SENT: Page Down';throw 'Game not foreground'}
Mark 'sent Page Down'
Start-Sleep -Seconds 5
'Gate capture finished.'
