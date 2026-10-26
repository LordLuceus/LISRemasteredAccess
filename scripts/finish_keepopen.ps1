# Finishes an interrupted keep-open session once the game exits: the same
# cleanup run_profile_probe.ps1 does after a session (copy the log, restore the
# normal request file and its manifest hash, check the real profile against the
# hashes taken before, release and archive the claim). Never touches the game.
param([Parameter(Mandatory=$true)][int]$GamePid,[Parameter(Mandatory=$true)][string]$SessionName)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$gameDir='C:/Program Files (x86)/Steam/steamapps/common/LIS - Remastered/LIS/Binaries/Win64'
$session=Join-Path $root "artifacts/$SessionName"
$runtime=Join-Path $root 'artifacts/runtime'; $operator=Join-Path $runtime 'operator-owner'
$claim=Get-Content (Join-Path $operator 'claim.json') -Raw | ConvertFrom-Json
if($claim.session -ne $SessionName){throw "Claim belongs to $($claim.session), not $SessionName"}
while(Get-Process -Id $GamePid -ErrorAction SilentlyContinue){Start-Sleep -Seconds 5}
Copy-Item (Join-Path $gameDir 'ue4ss/UE4SS.log') (Join-Path $session 'UE4SS.log') -Force
$requestPath=Join-Path $gameDir 'ue4ss/Mods/LISRemasteredAccess/Scripts/LISNavRequest.lua'
[IO.File]::WriteAllText($requestPath,"return {scene='inspect'}",[Text.UTF8Encoding]::new($false))
$mpath=Join-Path $root 'artifacts/ue4ss-install/installation/manifest.json'; $manifest=Get-Content $mpath -Raw | ConvertFrom-Json
$entry=$manifest.files | Where-Object {$_.relative -eq 'ue4ss\Mods\LISRemasteredAccess\Scripts\LISNavRequest.lua'}
$entry.installed_sha256=(Get-FileHash -LiteralPath $requestPath -Algorithm SHA256).Hash.ToLowerInvariant()
[IO.File]::WriteAllText($mpath,($manifest | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$before=Get-Content (Join-Path $session 'real-profile-before.json') -Raw | ConvertFrom-Json; $changed=@()
foreach($p in $before.PSObject.Properties){ if($p.Name -match 'steam_autocloud\.vdf$'){continue}; if(-not(Test-Path -LiteralPath $p.Name) -or (Get-FileHash -LiteralPath $p.Name).Hash -ne $p.Value){$changed+=$p.Name} }
@{early=$true;keep_open=$true;finished_by='finish_keepopen.ps1';real_profile_changed=$changed;at=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $session 'result.json')
New-Item -ItemType Directory -Force (Join-Path $session 'operator-owner') | Out-Null; 'RELEASED (keep-open, finished after game exit)' | Set-Content (Join-Path $session 'operator-owner/result.txt')
New-Item -ItemType Directory -Force (Join-Path $runtime 'operator-history') | Out-Null
Move-Item -LiteralPath $operator -Destination (Join-Path $runtime "operator-history/$SessionName")
"Game closed; test session cleaned up. Real profile files changed: $($changed.Count)."
