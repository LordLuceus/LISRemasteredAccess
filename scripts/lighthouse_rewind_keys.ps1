param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
# Guide-mode lighthouse test: the guide walks; when the guide says Max is
# caught (guide_lighthouse event=caught), hold R until the guide logs
# rewind_done; it then restarts by itself. Up to 3 rounds; stop on arrival.
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
$marks=Join-Path (Split-Path $LogPath) 'menu-keys.txt'
function Mark([string]$Text){Add-Content -LiteralPath $marks ("{0:HH:mm:ss.fff} {1}" -f (Get-Date),$Text)}
function Count([string]$P){@(Select-String -LiteralPath $LogPath -Pattern $P).Count}
$end=(Get-Date).AddSeconds(170);$rounds=0
try{
  while((Get-Date) -lt $end){
    $Game.Refresh();if($Game.HasExited){break}
    if((Count 'guide_lighthouse event=caught') -gt $rounds){
      $rounds++;Start-Sleep -Milliseconds 400
      $done=Count 'guide_lighthouse event=rewind_done'
      [void][LISKeyTest]::Down($Game.Id,0x52);Mark "R down round $rounds"
      $t0=Get-Date
      # Hold until the tree is standing again (the probe's ticks show LighthouseTree=0), or 10 s.
      $ticks=Count 'lighthouse tick'
      while(((Get-Date)-$t0).TotalSeconds -lt 10){
        Start-Sleep -Milliseconds 100
        $last=(Select-String -LiteralPath $LogPath -Pattern 'lighthouse tick' | Select-Object -Last 1).Line
        if((Count 'lighthouse tick') -gt $ticks -and $last -match 'LighthouseTree=0'){break}
      }
      [void][LISKeyTest]::Up(0x52);Mark "R up round $rounds after $([int]((Get-Date)-$t0).TotalMilliseconds) ms"
      if($rounds -ge 3){Start-Sleep -Seconds 20;break}
    }
    if((Count 'Arrived at|That''s the newspaper') -gt 0 -and (Count 'guide_lighthouse event=caught') -le $rounds){Start-Sleep -Seconds 2;if((Count 'That''s the newspaper|Arrived at Guide: the newspaper') -gt 0){Mark 'reached newspaper';break}}
    Start-Sleep -Milliseconds 150
  }
} finally {[void][LISKeyTest]::Up(0x52);Mark "finished rounds=$rounds"}
