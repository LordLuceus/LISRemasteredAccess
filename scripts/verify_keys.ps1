param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'key_injection.ps1')
function AwaitLog([string]$Text,[int]$Seconds=30){
    $end=(Get-Date).AddSeconds($Seconds)
    do{
        $Game.Refresh();if($Game.HasExited){throw 'Game exited during key verification'}
        if((Test-Path -LiteralPath $LogPath) -and (Select-String -LiteralPath $LogPath -SimpleMatch $Text -Quiet)){return}
        Start-Sleep -Milliseconds 100
    }while((Get-Date)-lt $end)
    throw "Key verification timeout: $Text"
}
AwaitLog "Chloe's house loaded."
$status=(Select-String -LiteralPath $LogPath -Pattern '\[LISNavSay\]' | Select-Object -Last 1).Line -replace '^.*\[LISNavSay\] ',''
$countBefore=@(Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] $status").Count
if(-not [LISKeyTest]::Press($Game.Id,0x24)){throw 'Game is not foreground; no Home input sent'}
Start-Sleep -Milliseconds 300
if(@(Select-String -LiteralPath $LogPath -SimpleMatch "[LISNavSay] $status").Count -le $countBefore){throw 'Home did not repeat status'}
if(-not [LISKeyTest]::Press($Game.Id,0x77)){throw 'Game is not foreground; no F8 input sent'}
AwaitLog 'key=F8' 5
if(-not [LISKeyTest]::Press($Game.Id,0x79)){throw 'Game is not foreground; no F10 input sent'}
AwaitLog '[LISNavSay] Returning to the main menu.' 5
AwaitLog '[LISNavSay] Main menu. Alt F4 exits the game.' 15
'Physical Home repeat, F8 cancellation and F10 menu callbacks verified.'
