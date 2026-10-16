param([switch]$SelfTest)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
$hotkeyCode=@'
using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;
using System.Drawing;

public sealed class DoongiHotkey : NativeWindow, IDisposable {
    [DllImport("user32.dll", SetLastError=true)]
    private static extern bool RegisterHotKey(IntPtr window, int id, uint modifiers, uint key);
    [DllImport("user32.dll")]
    private static extern bool UnregisterHotKey(IntPtr window, int id);
    private readonly string petScript;
    private NotifyIcon tray;
    private ContextMenuStrip menu;
    private DateTime lastLaunch=DateTime.MinValue;
    public DoongiHotkey(string script) {
        petScript=script;
        CreateHandle(new CreateParams { Caption="Doongi.Hotkey.CtrlM", Parent=new IntPtr(-3) });
        // MOD_CONTROL | MOD_NOREPEAT; virtual key M.
        if (!RegisterHotKey(Handle, 1, 0x4002, 0x4D)) {
            int error=Marshal.GetLastWin32Error();
            DestroyHandle();
            throw new InvalidOperationException("Ctrl+M registration failed (Win32 " + error + ").");
        }
    }
    public void ShowTray() {
        menu=new ContextMenuStrip();
        menu.Items.Add("끼끼 보이기 / 숨기기 · Ctrl+M", null, (s,e)=>LaunchPet());
        menu.Items.Add("단축키 도우미 종료", null, (s,e)=>Application.ExitThread());
        tray=new NotifyIcon { Icon=SystemIcons.Application, Text="끼끼 · Ctrl+M 보이기 / 숨기기", ContextMenuStrip=menu, Visible=true };
        tray.DoubleClick+=(s,e)=>LaunchPet();
    }
    public void LaunchPet() {
        if ((DateTime.UtcNow-lastLaunch).TotalMilliseconds<180) return;
        Mutex existing;
        if (Mutex.TryOpenExisting("Local\\Doongi.DesktopPet",out existing)) {
            existing.Dispose();
            EventWaitHandle toggle;
            if (EventWaitHandle.TryOpenExisting("Local\\Doongi.ToggleVisibility",out toggle)) {
                using(toggle) { toggle.Set(); }
                lastLaunch=DateTime.UtcNow;
            }
            return;
        }
        lastLaunch=DateTime.UtcNow;
        Process.Start(new ProcessStartInfo {
            FileName=System.IO.Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.System), @"WindowsPowerShell\v1.0\powershell.exe"),
            Arguments="-NoLogo -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File \""+petScript+"\"",
            UseShellExecute=false, CreateNoWindow=true, WindowStyle=ProcessWindowStyle.Hidden,
            WorkingDirectory=System.IO.Path.GetDirectoryName(petScript)
        });
    }
    protected override void WndProc(ref Message message) {
        if (message.Msg==0x0312 && message.WParam.ToInt32()==1) LaunchPet();
        base.WndProc(ref message);
    }
    public void Dispose() {
        UnregisterHotKey(Handle,1);
        if (tray!=null) { tray.Visible=false; tray.Dispose(); }
        if (menu!=null) menu.Dispose();
        DestroyHandle();
    }
}
'@
Add-Type -TypeDefinition $hotkeyCode -ReferencedAssemblies System.Windows.Forms,System.Drawing
$created=$false
$listenerMutex=[Threading.Mutex]::new($true,'Local\Doongi.HotkeyListener',[ref]$created)
if (-not $created) { $listenerMutex.Dispose(); exit 0 }
$listener=$null
try {
    $listener=[DoongiHotkey]::new((Join-Path $PSScriptRoot 'Doongi.ps1'))
    if ($SelfTest) { Write-Output 'PASS: Ctrl+M registered successfully.' }
    else {
        $listener.ShowTray()
        Write-Output ('READY: Ctrl+M; window=' + $listener.Handle.ToInt64())
        [Windows.Forms.Application]::Run()
    }
} finally {
    if ($null -ne $listener) { $listener.Dispose() }
    $listenerMutex.ReleaseMutex()
    $listenerMutex.Dispose()
}
