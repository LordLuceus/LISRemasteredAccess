param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Explores the in-game pause menu for read-only discovery, in a test scene.
# Escape opens the pause menu once the scene is announced. Inside it, W/S
# only, except: one Enter on "Settings" (opens the settings list, then Escape
# back) and one Enter on "Exit to main menu" (opens its confirmation, then
# Escape cancels it). Each Enter is sent only after the mod announced that
# exact option. "Reload last checkpoint" is never pressed. Throwaway profile.
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
function SeekDown([string]$Pattern,[string]$What,[int]$Max){
    $n=0;while(-not (Await $Pattern 1)){if(++$n -gt $Max){Mark "STOP: $What not reached";throw "$What not reached; stopping"};Press 0x53 "S (seek $What)"}
}
$W=0x57;$S=0x53;$Enter=0x0D;$Esc=0x1B
# Wait for the test scene (the session announces it), then let it settle.
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Chloe's house loaded" -Quiet)){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded; no keys sent'};Start-Sleep -Milliseconds 500
}
Start-Sleep -Seconds 4
Press $Esc 'Escape (open pause menu)'
if(-not (Await 'PauseMenu_Widget_C' 6)){Mark 'STOP: pause menu not announced';throw 'Pause menu not announced'}
foreach($i in 1..4){Press $S 'S'}
foreach($i in 1..4){Press $W 'W'}
SeekDown 'PauseMenu_Widget_C .*spoken=Settings$' 'Settings' 5
Press $Enter 'Enter (Settings)'; Start-Sleep -Seconds 1
Press $S 'S (settings list)'; Press $W 'W (settings list)'
Press $Esc 'Escape (back to pause menu)'
if(-not (Await 'PauseMenu_Widget_C' 6)){Mark 'STOP: not back on pause menu';throw 'Not back on pause menu'}
SeekDown 'PauseMenu_Widget_C .*spoken=Exit to main menu$' 'Exit to main menu' 6
Press $Enter 'Enter (Exit to main menu: opens confirmation only)'; Start-Sleep -Seconds 1
Press $Esc 'Escape (cancel confirmation)'
Press $Esc 'Escape (resume game)'
'Pause navigation finished.'
