param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Opens Settings and moves through the rows inside three categories, for
# read-only discovery. Enter and Escape are sent ONLY after the mod has
# announced the expected item; otherwise the script stops. Inside a category it
# sends W/S only: never Enter, Space, A or D (A/D may change values).
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Await([string]$Pattern,[int]$Seconds){
    $end=(Get-Date).AddSeconds($Seconds)
    do{
        $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
        $l=Select-String -LiteralPath $LogPath -Pattern 'menu_readout' | Select-Object -Last 1
        if($l -and $l.Line -match $Pattern){return $true}
        Start-Sleep -Milliseconds 200
    }while((Get-Date)-lt $end)
    return $false
}
function Press([uint16]$Key,[string]$Name){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT (game not foreground): $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds 2
}
function Require([string]$Pattern,[string]$What){
    if(-not (Await $Pattern 10)){Mark "STOP: $What not announced";throw "$What not announced; stopping"}
}
$list='Settings_Widget_C .*spoken='
if(-not (Await 'screen=title' 90)){throw 'Title screen never announced; no keys sent'}
Start-Sleep -Seconds 2
Press 0x53 'S (leave Click To Start)'
Require 'spoken=Episodes$' 'Episodes'
Press 0x53 'S'
Require 'spoken=Settings$' 'Settings'
Press 0x0D 'Enter (open Settings)'
Require ($list+'Saved games$') 'Settings list'
$categories=@(@{spoken='Video Settings';rows=@('S','S','S','S','S','S','S','S','W','W')},
              @{spoken='Audio & Language Settings';rows=@('S','S','S','S','S','S')},
              @{spoken='Game Settings';rows=@('S','S','S','S','S','S')})
$first=$true
foreach($c in $categories){
    if(-not $first){
        Press 0x1B 'Escape (back to Settings list)'
        if(-not (Await $list 10)){Mark 'STOP: Settings list not announced after Escape';throw 'Settings list not back after Escape; stopping'}
    }
    $first=$false
    # Move down the category list until the wanted category is highlighted.
    $tries=0
    while(-not (Await ($list+[regex]::Escape($c.label)+'$') 1)){
        if(++$tries -gt 5){Mark "STOP: $($c.label) not reached";throw "$($c.label) not reached; stopping"}
        Press 0x53 'S (category list)'
    }
    Press 0x0D "Enter (open $($c.label))"
    Start-Sleep -Seconds 1
    foreach($r in $c.rows){ if($r -eq 'S'){Press 0x53 'S'}else{Press 0x57 'W'} }
}
'Settings navigation finished.'
