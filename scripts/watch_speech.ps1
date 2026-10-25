param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
$dll=Join-Path $root 'artifacts/runtime-tools/nvdaControllerClient64.dll'
$synth=$null
if(Test-Path -LiteralPath $dll){
    if(-not ('LISPrototypeSpeech' -as [type])){
        $escaped=$dll.Replace('"','""')
        Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class LISPrototypeSpeech {
 [DllImport(@"$escaped", CallingConvention=CallingConvention.StdCall)] public static extern int nvdaController_testIfRunning();
 [DllImport(@"$escaped", CallingConvention=CallingConvention.StdCall,CharSet=CharSet.Unicode)] public static extern int nvdaController_speakText(string text);
}
"@
    }
}
function Speak([string]$Text){
    Write-Host $Text
    $spoken=$false
    if(('LISPrototypeSpeech' -as [type]) -and [LISPrototypeSpeech]::nvdaController_testIfRunning() -eq 0){
        $spoken=([LISPrototypeSpeech]::nvdaController_speakText($Text) -eq 0)
    }
    if(-not $spoken){
        if(-not $script:synth){Add-Type -AssemblyName System.Speech;$script:synth=[Speech.Synthesis.SpeechSynthesizer]::new()}
        $script:synth.SpeakAsyncCancelAll();[void]$script:synth.SpeakAsync($Text)
    }
}
$reader=$null
$script:native=$false
try{
    while(-not $Game.HasExited){
        if(-not $reader -and (Test-Path -LiteralPath $LogPath) -and (Get-Item -LiteralPath $LogPath).LastWriteTimeUtc -ge $Game.StartTime.ToUniversalTime()){
            $stream=[IO.File]::Open($LogPath,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite)
            $reader=[IO.StreamReader]::new($stream,[Text.Encoding]::UTF8)
        }
        if($reader){
            while($null -ne ($line=$reader.ReadLine())){
                # In-process speech takes over once the module reports it loaded;
                # the watcher then only stays as the fallback for a failed load.
                if($line -match 'speech_module native=true|loaded speech_module native=true'){$script:native=$true;Write-Host 'In-game speech module active.'}
                elseif($line -match '\[Lua\] \[LISNavSay\] (.+)$'){if($script:native){Write-Host $Matches[1]}else{Speak $Matches[1]}}
            }
        }
        Start-Sleep -Milliseconds 100
        $Game.Refresh()
    }
}finally{if($reader){$reader.Dispose()};if($script:synth){$script:synth.Dispose();$script:synth=$null}}
