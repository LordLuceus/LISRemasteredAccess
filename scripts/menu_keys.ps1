param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Non-confirming menu navigation for read-only menu discovery: W/S
# only, never Enter, Space or Escape. Each press is logged so focus changes in
# the game log can be matched to the key that caused them.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
function Mark([string]$Text){Add-Content -LiteralPath (Join-Path (Split-Path $LogPath) 'menu-keys.txt') ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
# The startup splash runs in the same menu world for ~45 s; wait for the title
# screen widget itself, not the world, before sending anything.
$deadline=(Get-Date).AddSeconds(90)
while((Get-Date)-lt $deadline -and -not (Select-String -LiteralPath $LogPath -SimpleMatch 'menu_state HighlightThisOption=' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};Start-Sleep -Milliseconds 250}
if(-not (Select-String -LiteralPath $LogPath -SimpleMatch 'menu_state HighlightThisOption=' -Quiet)){throw 'Title screen never appeared; no keys sent'}
Start-Sleep -Seconds 3 # let the title settle
# Menus navigate with W/S (the game's DPadUp/DPadDown actions), not arrows.
$sequence=@(@{k=0x53;n='S (any key: leave Click To Start)'},@{k=0x53;n='S'},@{k=0x53;n='S'},@{k=0x53;n='S'},@{k=0x57;n='W'},@{k=0x57;n='W'})
foreach($s in $sequence){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,[uint16]$s.k)){Mark "NOT SENT (game not foreground): $($s.n)";continue}
    Mark "sent $($s.n)";Start-Sleep -Seconds 3
}
'Menu navigation sequence finished.'
