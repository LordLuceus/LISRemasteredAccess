param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Opens the dialogs and screens that don't read yet, for read-only discovery:
# Saved games, the video Apply Settings confirmation, and the Exit confirmation.
# Every Enter and Escape is sent only after the mod announced the expected item.
# Inside a dialog it sends W/S only. It never confirms a dialog, never presses A,
# D or Space, and runs in a throwaway profile. Apply Settings applies unchanged
# values (no value was altered).
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
function Require([string]$Pattern,[string]$What,[int]$Seconds=10){if(-not (Await $Pattern $Seconds)){Mark "STOP: $What not announced";throw "$What not announced; stopping"}}
# Press S until the readout matches, at most $Max times.
function SeekDown([string]$Pattern,[string]$What,[int]$Max){
    $n=0;while(-not (Await $Pattern 1)){if(++$n -gt $Max){Mark "STOP: $What not reached";throw "$What not reached; stopping"};Press 0x53 "S (seek $What)"}
}
$S=0x53;$W=0x57;$Enter=0x0D;$Esc=0x1B
Require 'screen=title' 'title' 90; Start-Sleep -Seconds 2
Press $S 'S (leave Click To Start)'; Require 'spoken=Episodes$' 'Episodes'
Press $S 'S'; Require 'spoken=Settings$' 'Settings'
Press $Enter 'Enter (Settings)'; Require 'Settings_Widget_C .*spoken=Saved games$' 'Saved games'
# 1. Saved games: move through the slots.
Press $Enter 'Enter (Saved games)'; Start-Sleep -Seconds 1
Press $S 'S'; Press $S 'S'; Press $S 'S'; Press $W 'W'
Press $Esc 'Escape (back to Settings list)'; Require 'Settings_Widget_C .*spoken=' 'Settings list'
# 2. Video settings: Apply Settings, then the confirmation.
SeekDown 'Settings_Widget_C .*spoken=Video Settings$' 'Video Settings' 4
Press $Enter 'Enter (Video Settings)'; Start-Sleep -Seconds 1
SeekDown 'spoken=Apply Settings$' 'Apply Settings' 16
Press $Enter 'Enter (Apply Settings, unchanged values)'; Start-Sleep -Seconds 1
Press $S 'S (in confirmation)'; Press $W 'W (in confirmation)'
Press $Esc 'Escape (dismiss confirmation)'; Start-Sleep -Seconds 1
Press $Esc 'Escape (back to Settings list)'; Start-Sleep -Seconds 1
Press $Esc 'Escape (back to main menu)'
# 3. Exit confirmation, never confirmed.
SeekDown 'Start_Widget_C .*spoken=Exit$' 'Exit' 6
Press $Enter 'Enter (Exit: opens confirmation only)'; Start-Sleep -Seconds 1
Press $S 'S (in confirmation)'; Press $W 'W (in confirmation)'
Press $Esc 'Escape (cancel Exit confirmation)'
'Dialog navigation finished.'
