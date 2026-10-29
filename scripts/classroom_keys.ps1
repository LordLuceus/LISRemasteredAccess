param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Classroom facing test: once Max is playable, select each of the first five
# scanner entries (Camera, Journal, Bag, ...) with Page Down and press F, with
# time for the correction loop and the focused-object announcement. No actions.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Press([uint16]$Key,[string]$Name,[int]$Wait=2){
    $Game.Refresh();if($Game.HasExited){throw 'Game exited'}
    if(-not [LISKeyTest]::Press($Game.Id,$Key)){Mark "NOT SENT: $Name";throw "Game not foreground; stopped before $Name"}
    Mark "sent $Name";Start-Sleep -Seconds $Wait
}
$end=(Get-Date).AddSeconds(150)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] Classroom loaded" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){throw 'Scene never loaded'};Start-Sleep -Milliseconds 500}
# Wait for control (the "back" control event), up to two minutes.
$end=(Get-Date).AddSeconds(120)
while(-not (Select-String -LiteralPath $LogPath -SimpleMatch "[LISAccess] control back" -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){Mark 'control never came back; trying anyway';break};Start-Sleep -Milliseconds 500}
Start-Sleep -Seconds 2
# Idle first, so idle-triggered tutorial prompts can appear.
if($env:LISR_IDLE_SECONDS){Mark "idle $env:LISR_IDLE_SECONDS s";Start-Sleep -Seconds ([int]$env:LISR_IDLE_SECONDS)}
# Photo first (it gates the rest), then the camera and the journal.
# Select an entry by the start of its scanner name (Page Down, at most $Max steps).
function SelectNamed([string]$Prefix,[int]$Max=60){
    $last=(Select-String -LiteralPath $LogPath -Pattern 'scanner_readout spoken=' | Select-Object -Last 1).Line
    if($last -and $last -match ('spoken='+[regex]::Escape($Prefix))){return $true}
    for($i=0;$i -lt $Max;$i++){
        Press 0x22 'Page Down' 1
        $last=(Select-String -LiteralPath $LogPath -Pattern 'scanner_readout spoken=' | Select-Object -Last 1).Line
        if($last -match ('spoken='+[regex]::Escape($Prefix))){return $true}
    }
    Mark "not found in the scanner: $Prefix";return $false
}
# The photo on Max's desk is "Photo, B" (the closest one); the step count to it changes.
if(-not (SelectNamed 'Photo, B, ')){return}
Press 0x46 'F (Photo)' 5
Press 0x31 '1 (Look at photo)' 8
Press 0x1B 'Escape (close the photo)' 4
Press 0x21 'Page Up' 2;Press 0x21 'Page Up' 2;Press 0x21 'Page Up' 2;Press 0x46 'F (Camera)' 5
Press 0x22 'Page Down' 2;Press 0x46 'F (Journal)' 5
# Optional: take the selfie (camera, action 2), which starts Jefferson's question,
# then wait for the answers and choose the first announced one.
if($env:LISR_CHOICE){
    # Select the camera by name: Page Down until the scanner reads "Camera, ",
    # at most 60 steps, then face it and wait for its pop-up.
    if(-not (SelectNamed 'Camera, ')){return}
    Press 0x46 'F (Camera)' 6
    $pop=(Select-String -LiteralPath $LogPath -Pattern 'focus_announce spoken=' | Select-Object -Last 1).Line
    if($pop -notmatch 'spoken=Camera\.'){Mark "camera pop-up not focused: $pop";return}
    Press 0x32 '2 (Take Selfie)' 3
    $end=(Get-Date).AddSeconds(90)
    while(-not (Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] choice_announce' -Quiet)){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){Mark 'no choice announced';break};Start-Sleep -Milliseconds 500}
    Start-Sleep -Seconds 3
    if(Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] choice_announce' -Quiet){Press 0x31 '1 (first answer)' 10}
    # Optional: the second question in the same lesson, answered too.
    if($env:LISR_CHOICE -eq '2'){
        $end=(Get-Date).AddSeconds(120)
        while(@(Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] choice_announce').Count -lt 2){$Game.Refresh();if($Game.HasExited){throw 'Game exited'};if((Get-Date)-gt $end){Mark 'no second choice announced';break};Start-Sleep -Milliseconds 500}
        Start-Sleep -Seconds 3
        if(@(Select-String -LiteralPath $LogPath -SimpleMatch '[LISAccess] choice_announce').Count -ge 2){Press 0x31 '1 (second question, first answer)' 10}
    }
}
'Classroom face test finished.'