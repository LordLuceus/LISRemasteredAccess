param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Polled-keys check (Main Campus): Page Down, Home, held Page Down, Ctrl+Home, F1, Shift+Home,
# then F to face. Each must produce its spoken result in the log.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Count([string]$P){@(Select-String -LiteralPath $LogPath -Pattern $P).Count}
function Expect([string]$Name,[string]$Pattern,[int]$Before){
    $end=(Get-Date).AddSeconds(4)
    while((Count $Pattern) -le $Before){ if((Get-Date) -gt $end){Mark "FAIL $Name";return};Start-Sleep -Milliseconds 200 }
    Mark "PASS $Name"
}
$end=(Get-Date).AddSeconds(180)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] control back' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Control never returned'};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 2
$b=Count 'scanner_readout spoken=';[void][LISKeyTest]::Press($Game.Id,0x22);Expect 'Page Down' 'scanner_readout spoken=' $b;Start-Sleep 1
$b=Count 'scanner_readout spoken=';[void][LISKeyTest]::Press($Game.Id,0x24);Expect 'Home' 'scanner_readout spoken=' $b;Start-Sleep 1
# Held Page Down for 1.2 s: one press + repeats from 0.45 s every 0.18 s = about 5 readouts.
$b=Count 'scanner_readout spoken=';[void][LISKeyTest]::Hold($Game.Id,0x22,1200);Start-Sleep 1
$n=(Count 'scanner_readout spoken=')-$b;if($n -ge 3){Mark "PASS held Page Down repeats ($n readouts)"}else{Mark "FAIL held Page Down repeats ($n readouts)"};Start-Sleep 1
$b=Count '\[LISNavSay\]';[void][LISKeyTest]::PressWithControl($Game.Id,0x24);Expect 'Ctrl+Home' '\[LISNavSay\]' $b;Start-Sleep 1
$b=Count '\[LISNavSay\]';[void][LISKeyTest]::Press($Game.Id,0x70);Expect 'F1' '\[LISNavSay\]' $b;Start-Sleep 2
$b=Count 'autowalk start';[void][LISKeyTest]::PressWithShift($Game.Id,0x24);Expect 'Shift+Home' 'autowalk start' $b;Start-Sleep 8
$b=Count 'face requested';[void][LISKeyTest]::Press($Game.Id,0x46);Expect 'F' 'face requested' $b;Start-Sleep 2
$fails=(Select-String -LiteralPath $marks -Pattern 'FAIL ' | Measure-Object).Count
"Polled keys finished. failures=$fails"
