param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Opens the chapter (scene) list for read-only discovery, without starting play.
# Path verified in the game's own blueprint (BP_LiS_ChangeEpisode_Widget): the
# Collectible Mode option only checks the episode is installed, sets collector
# mode and calls MoveToSceneSelection, which creates and shows the chapter list.
# Continue (LoadLastCheckpoint) and Restart (confirmation) are never pressed.
# Each Enter is sent only after the mod announced the expected item. Inside the
# chapter list: A/D/W/S only, never Enter or Space. Escape backs out. Throwaway profile.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Last{(Select-String -LiteralPath $LogPath -Pattern 'menu_readout' | Select-Object -Last 1).Line}
function Await([string]$Pattern,[int]$Seconds){
    $end=(Get-Date).AddSeconds($Seconds)
    do{$Game.Refresh();if($Game.HasExited){throw 'Game exited'};$l=Last;if($l -and $l -match $Pattern){return $true};Start-Sleep -Milliseconds 200}while((Get-Date)-lt $end)
    return $false
}
function Press([uint16]$Key,[string]$Name){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds 2
}
function Require([string]$Pattern,[string]$What){if(-not (Await $Pattern 8)){Mark "STOP: $What not announced";throw "$What not announced; stopping"}}
$W=0x57;$A=0x41;$S=0x53;$D=0x44;$Enter=0x0D;$Esc=0x1B
if(-not (Await 'screen=title' 90)){throw 'Title screen never announced; no keys sent'}
Start-Sleep -Seconds 2
Press $S 'S (leave Click To Start)'; Require 'spoken=Episodes$' 'Episodes'
Press $Enter 'Enter (open Episodes)'; Require 'ChangeEpisode_Widget_C .*spoken=.*Continue$' 'Episodes screen'
# Collectible Mode is the second option (verified: Continue, Collectible Mode, Restart).
Press $S 'S (to Collectible Mode)'; Require 'ChangeEpisode_Widget_C .*spoken=Collectible Mode$' 'Collectible Mode'
Press $Enter 'Enter (Collectible Mode: opens the chapter list only)'
Start-Sleep -Seconds 3
foreach($i in 1..4){Press $D 'D (next chapter)'}
foreach($i in 1..2){Press $A 'A (previous chapter)'}
Press $S 'S'; Press $S 'S'; Press $W 'W'; Press $W 'W'
Press $Esc 'Escape (back)'; Start-Sleep -Seconds 2
Press $Esc 'Escape (back)'
'Chapter navigation finished.'
