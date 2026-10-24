$ErrorActionPreference='Stop'
if(Get-Process 'LiS-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Close the remaster before rollback'}
$root=Split-Path $PSScriptRoot -Parent
$record=Join-Path $root 'artifacts/ue4ss-install/installation'
$manifest=Get-Content -Raw -LiteralPath (Join-Path $record 'manifest.json') | ConvertFrom-Json
$game=[IO.Path]::GetFullPath($manifest.game)
$backupRoot=[IO.Path]::GetFullPath((Join-Path $record 'files-before'))
$actions=@()
foreach($entry in $manifest.files){
    $target=[IO.Path]::GetFullPath((Join-Path $game $entry.relative))
    if(-not $target.StartsWith($game+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe installed path'}
    if(-not(Test-Path -LiteralPath $target -PathType Leaf)){throw "Installed file missing; inspect before rollback: $target"}
    if((Get-FileHash -LiteralPath $target -Algorithm SHA256).Hash -ne $entry.installed_sha256){throw "File changed after installation; refusing to overwrite: $target"}
    $backup=$null
    if($entry.previous_sha256){
        $backup=[IO.Path]::GetFullPath((Join-Path $backupRoot $entry.relative))
        if(-not $backup.StartsWith($backupRoot+[IO.Path]::DirectorySeparatorChar,[StringComparison]::OrdinalIgnoreCase)){throw 'Unsafe backup path'}
        if((Get-FileHash -LiteralPath $backup -Algorithm SHA256).Hash -ne $entry.previous_sha256){throw "Backup mismatch: $backup"}
    }
    $actions+=@{target=$target;backup=$backup;previous=$entry.previous_sha256}
}
# All checks above precede any filesystem change. Saves are deliberately excluded.
foreach($action in $actions){
    if($action.backup){
        Copy-Item -LiteralPath $action.backup -Destination $action.target -Force
        if((Get-FileHash -LiteralPath $action.target -Algorithm SHA256).Hash -ne $action.previous){throw 'Restore verification failed'}
    }else{
        Remove-Item -LiteralPath $action.target
        if(Test-Path -LiteralPath $action.target){throw 'Removal verification failed'}
    }
}
@{rolled_back_at=(Get-Date).ToString('o');files=$actions.Count;saves_restored=$false} | ConvertTo-Json | Set-Content (Join-Path $record 'rollback-result.json') -Encoding UTF8
'UE4SS installation rolled back. Saves were not restored or modified; generated logs/cache and empty directories were retained.'
