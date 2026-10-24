param([Parameter(Mandatory=$true)][Diagnostics.Process]$Game,[Parameter(Mandatory=$true)][string]$LogPath)
$ErrorActionPreference='Stop'
Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class LISKeyTest {
 [StructLayout(LayoutKind.Sequential)] public struct MOUSEINPUT { public int dx,dy;public uint data,flags,time;public UIntPtr extra; }
 [StructLayout(LayoutKind.Sequential)] public struct KEYBDINPUT { public ushort vk,scan;public uint flags,time;public UIntPtr extra; }
 [StructLayout(LayoutKind.Explicit)] public struct UNION { [FieldOffset(0)] public MOUSEINPUT mouse;[FieldOffset(0)] public KEYBDINPUT key; }
 [StructLayout(LayoutKind.Sequential)] public struct INPUT {public uint type;public UNION value;}
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr window,out uint pid);
 [DllImport("user32.dll",SetLastError=true)] public static extern uint SendInput(uint count,INPUT[] inputs,int size);
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
 public static bool Press(uint expectedPid,ushort key) {
  uint pid;GetWindowThreadProcessId(GetForegroundWindow(),out pid);if(pid!=expectedPid)return false;
  foreach(int mod in new int[]{0x10,0x11,0x12}){short state=GetAsyncKeyState(mod);Console.WriteLine("Modifier {0:X}: {1:X4}",mod,state);if((state & 0x8000)!=0)return false;}
  INPUT[] inputs=new INPUT[2];inputs[0].type=inputs[1].type=1;
  inputs[0].value.key.vk=inputs[1].value.key.vk=key;inputs[1].value.key.flags=2;
  if(key==0x24){inputs[0].value.key.flags|=1;inputs[1].value.key.flags|=1;}
  bool down=SendInput(1,new INPUT[]{inputs[0]},Marshal.SizeOf(typeof(INPUT)))==1;
  try{System.Threading.Thread.Sleep(80);Console.WriteLine("Injected key {0:X}: count={1} state={2:X4} size={3}",key,down,GetAsyncKeyState(key),Marshal.SizeOf(typeof(INPUT)));System.Threading.Thread.Sleep(420);}finally{SendInput(1,new INPUT[]{inputs[1]},Marshal.SizeOf(typeof(INPUT)));}
  return down;
 }
}
'@
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
