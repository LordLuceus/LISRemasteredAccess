param([Parameter(Mandatory=$true)][string]$SessionName,[ValidateSet('inspect','garage','junkyard')][string]$Scene='inspect',[switch]$Follow,[switch]$KeepOpen,[switch]$VerifyKeys,[ValidatePattern('^[A-Za-z0-9_]*$')][string]$TargetActor='',[switch]$FaceTarget,[switch]$InspectWidgets,[ValidatePattern('^[A-Za-z0-9_,]*$')][string]$ActionPatterns='',[ValidatePattern('^[-0-9.,; ]*$')][string]$RouteCandidates='',[ValidatePattern('^[-0-9.,; ]*$')][string]$RouteWaypoints='',[ValidatePattern('^[-0-9.,]*$')][string]$AutoGoal='',[ValidateRange(60,300)][int]$DurationSeconds=60)
$ErrorActionPreference='Stop'
if($SessionName -notmatch '^profile-probe-[a-z0-9-]+$'){throw 'Invalid session name'}
if(Get-Process 'LiS-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Close the remaster before a profile probe'}
$root=Split-Path $PSScriptRoot -Parent
$runtime=Join-Path $root 'artifacts/runtime'
New-Item -ItemType Directory -Path $runtime -Force | Out-Null
$operator=Join-Path $runtime 'operator-owner'
New-Item -ItemType Directory -Path $operator -ErrorAction Stop | Out-Null
@{token=[guid]::NewGuid().ToString();operator_pid=$PID;runtime_pid=(Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId;session=$SessionName;started=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $operator 'claim.json') -Encoding UTF8
if(Get-Process 'LiS-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Game appeared after claim; will not take control'}
$session=Join-Path $root ('artifacts/'+$SessionName)
New-Item -ItemType Directory -Path (Join-Path $session 'operator-owner') -ErrorAction Stop | Out-Null
$profile=Join-Path $session 'profile'
$source=Join-Path $env:LOCALAPPDATA 'LiS/Saved'
$manifest=Get-Content -Raw -LiteralPath (Join-Path $root 'artifacts/ue4ss-install/installation/manifest.json') | ConvertFrom-Json
$gameDir=$manifest.game
$exe=Join-Path $gameDir 'LiS-Win64-Shipping.exe'
foreach($item in $manifest.files){
    $installed=Join-Path $gameDir $item.relative
    if(-not(Test-Path -LiteralPath $installed) -or (Get-FileHash -LiteralPath $installed -Algorithm SHA256).Hash -ne $item.installed_sha256){throw "Installed prototype file changed: $($item.relative)"}
}
$before=@{}
foreach($folder in @('SaveGames','Config/WindowsNoEditor')){
    $from=Join-Path $source $folder
    foreach($file in Get-ChildItem -LiteralPath $from -File -Recurse){
        $before[$file.FullName]=(Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash
        if($file.Name -eq 'steam_autocloud.vdf'){continue}
        $relative=$file.FullName.Substring($source.Length).TrimStart('\','/')
        $target=Join-Path (Join-Path $profile 'Saved') $relative
        New-Item -ItemType Directory -Path (Split-Path $target -Parent) -Force | Out-Null
        Copy-Item -LiteralPath $file.FullName -Destination $target
        if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $before[$file.FullName]){throw 'Profile copy mismatch'}
    }
}
$before | ConvertTo-Json | Set-Content (Join-Path $session 'real-profile-before.json') -Encoding UTF8
$saved=(Join-Path $profile 'Saved').Replace('\','/')
if($saved.Contains(']====]')){throw 'Unexpected delimiter in profile path'}
$requestPath=Join-Path $gameDir 'ue4ss/Mods/EngineTickProbe/Scripts/LISNavRequest.lua'
$followText=if($Follow){'true'}else{'false'}
$liveText=if($KeepOpen -or $VerifyKeys){'true'}else{'false'}
$returnText=if($KeepOpen){'false'}else{'true'}
$returnPoll=[math]::Floor(($DurationSeconds-15)/5);$maxPolls=[math]::Ceiling($DurationSeconds/5)+2;$followTicks=$DurationSeconds*4
function Add-RequestField([string]$Text){
    # Remove exactly the outer closing brace; nested tables keep theirs.
    if(-not $Text.EndsWith('}')){throw 'Malformed request text'}
    return $Text.Substring(0,$Text.Length-1)
}
$requestText="return {scene='$Scene', follow=$followText, live=$liveText, return_menu=$returnText, return_poll=$returnPoll, max_polls=$maxPolls, follow_ticks=$followTicks, expected_saved_directory=[====[$saved]====]}"
if($TargetActor){$faceText=if($FaceTarget){'true'}else{'false'};$requestText=(Add-RequestField $requestText)+", target_actor='$TargetActor', face_target=$faceText}"}
function ConvertTo-LuaPoints([string]$Text){
    $items=@()
    foreach($chunk in ($Text -split ';')){
        $chunk=$chunk.Trim();if(-not $chunk){continue}
        $n=@($chunk -split ',' | ForEach-Object {[double]::Parse($_.Trim(),[Globalization.CultureInfo]::InvariantCulture)})
        if($n.Count -ne 3){throw "Point needs X,Y,Z: $chunk"}
        $items+=('{'+(($n | ForEach-Object {$_.ToString([Globalization.CultureInfo]::InvariantCulture)}) -join ',')+'}')
    }
    if($items.Count -eq 0 -or $items.Count -gt 24){throw 'Expected 1-24 points'}
    return '{'+($items -join ',')+'}'
}
if($ActionPatterns){$list=(($ActionPatterns -split ',') | Where-Object {$_} | ForEach-Object {"'$_'"}) -join ',';$requestText=(Add-RequestField $requestText)+", action_patterns={$list}}"}
if($AutoGoal){if(-not $Follow){throw 'AutoGoal requires -Follow'};$g=(ConvertTo-LuaPoints $AutoGoal);$requestText=(Add-RequestField $requestText)+", auto_goal=$($g.Substring(1,$g.Length-2))}"}
if($InspectWidgets){$requestText=(Add-RequestField $requestText)+", inspect_widgets=true}"}
if($RouteCandidates){$requestText=(Add-RequestField $requestText)+", route_candidates=$(ConvertTo-LuaPoints $RouteCandidates)}"}
if($RouteWaypoints){if(-not $Follow){throw 'Route waypoints require -Follow'};$requestText=(Add-RequestField $requestText)+", route_waypoints=$(ConvertTo-LuaPoints $RouteWaypoints)}"}
[IO.File]::WriteAllText($requestPath,$requestText,[Text.UTF8Encoding]::new($false))
[IO.File]::WriteAllText((Join-Path $session 'request.lua'),$requestText,[Text.UTF8Encoding]::new($false))
@{token=[guid]::NewGuid().ToString();operator_pid=$PID;runtime_pid=(Get-CimInstance Win32_Process -Filter "ProcessId=$PID").ParentProcessId;purpose='isolated scene access and explicitly selected native navigation test';profile=$profile;scene=$Scene;follow=[bool]$Follow;interactive=[bool]$KeepOpen;started=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $session 'operator-owner/claim.json') -Encoding UTF8
$steam=Join-Path ${env:ProgramFiles(x86)} 'Steam/steam.exe'
$argument='-applaunch 1265920 -UserDir="'+$profile.Replace('\','/')+'" -nosteam'
Start-Process -FilePath $steam -ArgumentList $argument -WindowStyle Hidden
$deadline=(Get-Date).AddSeconds(45)
$game=$null
do {Start-Sleep -Milliseconds 500;$game=Get-Process 'LiS-Win64-Shipping' -ErrorAction SilentlyContinue} while(-not $game -and (Get-Date)-lt $deadline)
if(-not $game){throw 'Game did not start'}
if(@($game).Count -ne 1 -or $game.Path -ne $exe){throw 'Game identity mismatch'}
$handle=$game.Handle
$birth=$game.StartTime.ToUniversalTime().ToString('o')
$command=(Get-CimInstance Win32_Process -Filter "ProcessId=$($game.Id)").CommandLine
@{pid=$game.Id;start=$birth;exe=$game.Path;base_address=$game.MainModule.BaseAddress.ToInt64();command_line=$command} | ConvertTo-Json | Set-Content (Join-Path $session 'game.json') -Encoding UTF8
$profileArgumentPresent=$command -like '*UserDir*'
if($command.Replace('\','/').IndexOf($profile.Replace('\','/'),[StringComparison]::OrdinalIgnoreCase) -lt 0){throw 'Game does not carry this operator profile; will not control it'}
$keyVerification='not_requested'
if($VerifyKeys){
    try{& (Join-Path $PSScriptRoot 'verify_keys.ps1') -Game $game -LogPath (Join-Path $gameDir $manifest.loader_log);$keyVerification='passed'}
    catch{$keyVerification=$_.Exception.Message;Write-Warning $keyVerification}
}
if($KeepOpen){
    'Leave this launcher running. F8 stops the test; F10 returns to the menu; Home repeats status. At the menu, Alt+F4 exits.'
    & (Join-Path $PSScriptRoot 'watch_speech.ps1') -Game $game -LogPath (Join-Path $gameDir $manifest.loader_log)
    $game.WaitForExit();$early=$true
}else{
    $remaining=[math]::Max(0,$DurationSeconds*1000-((Get-Date)-$game.StartTime).TotalMilliseconds)
    $early=$game.WaitForExit([int]$remaining)
}
if(-not $early){
    $game.Refresh()
    if($game.StartTime.ToUniversalTime().ToString('o') -ne $birth){throw 'Game identity changed'}
    "Window title=$($game.MainWindowTitle) HWND=$($game.MainWindowHandle)"
    "Normal close requested=$($game.CloseMainWindow())"
    if(-not $game.WaitForExit(20000)){throw 'Normal close failed; no forced termination performed'}
}
$changed=@()
foreach($path in $before.Keys){
    if(-not(Test-Path -LiteralPath $path) -or (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -ne $before[$path]){$changed+=$path}
}
foreach($folder in @('SaveGames','Config/WindowsNoEditor')){
    foreach($file in Get-ChildItem -LiteralPath (Join-Path $source $folder) -File -Recurse){if(-not $before.ContainsKey($file.FullName)){$changed+=$file.FullName}}
}
@{exit_code=$game.ExitCode;early=$early;profile_argument_present=$profileArgumentPresent;real_profile_changed=$changed;key_verification=$keyVerification;at=(Get-Date).ToString('o')} | ConvertTo-Json | Set-Content (Join-Path $session 'result.json') -Encoding UTF8
$log=Join-Path $gameDir $manifest.loader_log
if(Test-Path -LiteralPath $log){Copy-Item -LiteralPath $log -Destination (Join-Path $session 'UE4SS.log')}
'RELEASED' | Set-Content (Join-Path $session 'operator-owner/result.txt')
[IO.File]::WriteAllText($requestPath,"return {scene='inspect'}",[Text.UTF8Encoding]::new($false))
$requestRelative='ue4ss\Mods\EngineTickProbe\Scripts\LISNavRequest.lua'
$requestHash=(Get-FileHash -LiteralPath $requestPath -Algorithm SHA256).Hash.ToLowerInvariant()
$entry=$manifest.files | Where-Object {$_.relative -eq $requestRelative}
if($entry){$entry.installed_sha256=$requestHash}else{$manifest.files+=@{relative=$requestRelative;installed_sha256=$requestHash;previous_sha256=$null}}
[IO.File]::WriteAllText((Join-Path $root 'artifacts/ue4ss-install/installation/manifest.json'),($manifest | ConvertTo-Json -Depth 8),[Text.UTF8Encoding]::new($false))
$history=Join-Path $runtime 'operator-history'
New-Item -ItemType Directory -Path $history -Force | Out-Null
$destination=Join-Path $history $SessionName
if(-not [IO.Path]::GetFullPath($destination).StartsWith([IO.Path]::GetFullPath($runtime)+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe claim archive path'}
Move-Item -LiteralPath $operator -Destination $destination
"Profile probe exit=$($game.ExitCode) early=$early real_profile_changed=$($changed.Count)"
if($changed.Count -ne 0){throw 'Real profile changes detected; see result.json. No automatic restoration attempted.'}
