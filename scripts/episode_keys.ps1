param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Explores the Episodes screen for read-only discovery with W/S/A/D, and tests
# arrow mirroring with single arrow presses whose effect is checked in the log.
# One Enter opens Episodes, sent only after the mod announced "Episodes". It
# never starts, restarts or continues an episode: no further Enter, no Space.
# Escape backs out. Throwaway profile.
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
$W=0x57;$A=0x41;$S=0x53;$D=0x44;$Up=0x26;$Down=0x28;$Left=0x25;$Right=0x27;$Enter=0x0D;$Esc=0x1B
if(-not (Await 'screen=title' 90)){throw 'Title screen never announced; no keys sent'}
Start-Sleep -Seconds 2
Press $S 'S (leave Click To Start)'
if(-not (Await 'spoken=Episodes$' 10)){Mark 'STOP: Episodes not announced';throw 'Episodes not announced'}
# Arrow mirroring check: Down arrow should reach Settings, Up arrow back.
Press $Down 'Down arrow (expect Settings)'; Mark "arrow Down reached Settings: $(Await 'spoken=Settings$' 3)"
Press $Up 'Up arrow (expect Episodes)'; Mark "arrow Up reached Episodes: $(Await 'spoken=Episodes$' 3)"
if(-not (Await 'spoken=Episodes$' 1)){ Press $W 'W'; if(-not (Await 'spoken=Episodes$' 4)){Mark 'STOP: cannot return to Episodes';throw 'Episodes not highlighted'} }
Press $Enter 'Enter (open Episodes)'
Start-Sleep -Seconds 3
# Episode cards with D/A, options with S/W.
foreach($i in 1..3){Press $D 'D (next episode)'}
foreach($i in 1..3){Press $A 'A (previous episode)'}
foreach($i in 1..3){Press $S 'S (next option)'}
foreach($i in 1..3){Press $W 'W (previous option)'}
# Arrow mirroring check inside Episodes.
Press $Right 'Right arrow (expect next episode)'
Press $Left 'Left arrow (expect previous episode)'
Press $Esc 'Escape (back)'
Start-Sleep -Seconds 2
if(-not (Await 'Start_Widget_C' 3)){Press $Esc 'Escape (back to main menu)'}
'Episode navigation finished.'
