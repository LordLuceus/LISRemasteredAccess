# Shared SendInput helper: sends one key only when the game window is in the
# foreground and no modifier is held; returns false otherwise.
if(-not ('LISKeyTest' -as [type])){
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
  // Extended keys (arrows, Insert/Delete, Home/End, Page Up/Down) need KEYEVENTF_EXTENDEDKEY.
  // Without it Windows delivers the numeric keypad key instead (NVDA then runs its numpad
  // review commands and the game never sees an arrow).
  if(key>=0x21&&key<=0x28||key==0x2D||key==0x2E){inputs[0].value.key.flags|=1;inputs[1].value.key.flags|=1;}
  bool down=SendInput(1,new INPUT[]{inputs[0]},Marshal.SizeOf(typeof(INPUT)))==1;
  try{System.Threading.Thread.Sleep(80);Console.WriteLine("Injected key {0:X}: count={1} state={2:X4} size={3}",key,down,GetAsyncKeyState(key),Marshal.SizeOf(typeof(INPUT)));System.Threading.Thread.Sleep(420);}finally{SendInput(1,new INPUT[]{inputs[1]},Marshal.SizeOf(typeof(INPUT)));}
  return down;
 }
 // Shift+key: holds Left Shift around one press.
 public static bool PressWithShift(uint expectedPid,ushort key) {
  uint pid;GetWindowThreadProcessId(GetForegroundWindow(),out pid);if(pid!=expectedPid)return false;
  INPUT[] sh=new INPUT[2];sh[0].type=sh[1].type=1;sh[0].value.key.vk=sh[1].value.key.vk=0xA0;sh[1].value.key.flags=2;
  if(SendInput(1,new INPUT[]{sh[0]},Marshal.SizeOf(typeof(INPUT)))!=1)return false;
  try{System.Threading.Thread.Sleep(60);
   INPUT[] k=new INPUT[2];k[0].type=k[1].type=1;k[0].value.key.vk=k[1].value.key.vk=key;k[1].value.key.flags=2;
   if(key>=0x21&&key<=0x28||key==0x2D||key==0x2E){k[0].value.key.flags|=1;k[1].value.key.flags|=1;}
   SendInput(1,new INPUT[]{k[0]},Marshal.SizeOf(typeof(INPUT)));System.Threading.Thread.Sleep(120);SendInput(1,new INPUT[]{k[1]},Marshal.SizeOf(typeof(INPUT)));
   System.Threading.Thread.Sleep(60);
  }finally{SendInput(1,new INPUT[]{sh[1]},Marshal.SizeOf(typeof(INPUT)));}
  return true;
 }
 // Ctrl+key: holds Left Ctrl (an ordinary, non-extended key) around one press.
 public static bool PressWithControl(uint expectedPid,ushort key) {
  uint pid;GetWindowThreadProcessId(GetForegroundWindow(),out pid);if(pid!=expectedPid)return false;
  INPUT[] ctrl=new INPUT[2];ctrl[0].type=ctrl[1].type=1;ctrl[0].value.key.vk=ctrl[1].value.key.vk=0xA2;ctrl[1].value.key.flags=2;
  if(SendInput(1,new INPUT[]{ctrl[0]},Marshal.SizeOf(typeof(INPUT)))!=1)return false;
  try{System.Threading.Thread.Sleep(60);
   INPUT[] k=new INPUT[2];k[0].type=k[1].type=1;k[0].value.key.vk=k[1].value.key.vk=key;k[1].value.key.flags=2;
   if(key>=0x21&&key<=0x28||key==0x2D||key==0x2E){k[0].value.key.flags|=1;k[1].value.key.flags|=1;}
   SendInput(1,new INPUT[]{k[0]},Marshal.SizeOf(typeof(INPUT)));System.Threading.Thread.Sleep(120);SendInput(1,new INPUT[]{k[1]},Marshal.SizeOf(typeof(INPUT)));
   System.Threading.Thread.Sleep(60);
  }finally{SendInput(1,new INPUT[]{ctrl[1]},Marshal.SizeOf(typeof(INPUT)));}
  return true;
 }
}
'@
}
