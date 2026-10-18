$ErrorActionPreference='Stop'
$root=Split-Path $PSScriptRoot -Parent
. (Join-Path $root 'Runtime.ps1')
Add-Type @'
using System;
using System.Collections.Concurrent;
using System.Threading;
public sealed class KikkiTestContext : SynchronizationContext {
    private readonly ConcurrentQueue<Action> queue = new ConcurrentQueue<Action>();
    public readonly AutoResetEvent Posted = new AutoResetEvent(false);
    public override void Post(SendOrPostCallback callback, object state) {
        queue.Enqueue(() => callback(state)); Posted.Set();
    }
    public void Pump() { Action action; while (queue.TryDequeue(out action)) action(); }
}
public sealed class KikkiTestTimer {
    public bool IsEnabled;
    public TimeSpan Interval;
    public void Start() { IsEnabled = true; }
    public void Stop() { IsEnabled = false; }
}
'@
$checks=0
function Assert($condition,$message) {
    if (-not $condition) { throw $message }
    $script:checks++
}
Assert ([KikkiUpdateSchedule]::FrameMilliseconds($false,$true,$true) -eq 0) 'Hidden animation must stop'
Assert ([KikkiUpdateSchedule]::FrameMilliseconds($true,$true,$true) -eq 33) 'Active movement must retain 30 FPS'
Assert ([KikkiUpdateSchedule]::FrameMilliseconds($true,$true,$false) -eq 67) 'Idle movement must use 15 FPS'
Assert ([KikkiUpdateSchedule]::FrameMilliseconds($true,$false,$true) -eq 100) 'Reduced motion must use 10 Hz'
$script:timer=[KikkiTestTimer]::new()
$script:classTimer=[KikkiTestTimer]::new()
$script:window=[pscustomobject]@{IsVisible=$true}
$script:clock=[Diagnostics.Stopwatch]::StartNew()
$script:motion=$true
$script:sulkEnd=0
$script:classEnd=$null
$script:pendingClassEnd=$false
Sync-PetTimers
Assert ($script:timer.IsEnabled -and $script:timer.Interval.TotalMilliseconds -eq 67) 'Visible idle schedule was not applied'
$script:window.IsVisible=$false
Sync-PetTimers
Assert (-not $script:timer.IsEnabled -and -not $script:classTimer.IsEnabled) 'Hidden idle pet retained a polling timer'
$script:classEnd=[DateTime]::Now.AddMinutes(50)
Sync-PetTimers
Assert (-not $script:timer.IsEnabled -and $script:classTimer.IsEnabled) 'Hidden class needs one deadline, not animation polling'
$script:classEnd=[DateTime]::Now.AddSeconds(-1)
Complete-ClassTimer
Sync-PetTimers
Assert ($script:pendingClassEnd -and $null -eq $script:classEnd -and -not $script:classTimer.IsEnabled) 'Hidden class completion was lost or left a timer'
$script:window.IsVisible=$true
$script:motion=$false
Sync-PetTimers
Assert ($script:timer.IsEnabled -and $script:timer.Interval.TotalMilliseconds -eq 100) 'Reduced-motion schedule was not applied'
$signal=[Threading.AutoResetEvent]::new($false)
$context=[KikkiTestContext]::new()
$script:deliveries=0
$thread=[Threading.Thread]::CurrentThread.ManagedThreadId
$watcher=[KikkiEventWatcher]::new($signal,$context,[Action]{
    if ([Threading.Thread]::CurrentThread.ManagedThreadId -ne $thread) { throw 'Callback escaped the UI context' }
    $script:deliveries++
})
try {
    [void]$signal.Set()
    Assert ($context.Posted.WaitOne(2000)) 'Signal was not delivered without an animation timer'
    Assert ($script:deliveries -eq 0) 'Worker thread ran PowerShell before dispatch'
    $context.Pump()
    Assert ($script:deliveries -eq 1) 'Signal did not dispatch exactly once'
    [void]$signal.Set()
    Assert ($context.Posted.WaitOne(2000)) 'Second visibility signal was lost'
    $watcher.Dispose()
    $context.Pump()
    Assert ($script:deliveries -eq 1) 'Queued callback ran after shutdown'
    $watcher.Dispose()
} finally {
    $watcher.Dispose(); $signal.Dispose(); $context.Posted.Dispose()
}
. (Join-Path $root 'Behavior.ps1')
$script:rng=[Random]::new(42)
foreach ($mode in 0..3) {
    foreach ($roll in 0..11) {
        $next=Get-NextActivityMode $mode -1 $roll
        Assert ($next -ne $mode) 'Automatic life repeated the same activity'
        if ($mode -ne 2) {
            $previous=($mode+1)%4
            Assert ((Get-NextActivityMode $mode $previous $roll) -ne $previous) 'Automatic life bounced straight back'
        }
    }
    $seconds=Get-ActivitySeconds $mode
    Assert ($seconds -ge 120 -and $seconds -le 240) 'Activity must last two to four minutes'
    foreach ($sample in 1..20) {
        $hold=Get-RestHoldSeconds $mode
        $delay=Get-FirstRestDelay $mode
        if ($mode -in @(1,2)) {
            Assert ($hold -ge 120 -and $hold -le 210) 'Side rest must last two to three and a half minutes'
            Assert ($delay -ge 25 -and $delay -le 55) 'Lying activities must turn to the side within 25 to 55 seconds'
        } else {
            Assert ($hold -eq 4) 'Eating and gaming details unexpectedly became long rest scenes'
            Assert ($delay -ge 120 -and $delay -le 240) 'Non-resting activities received rapid posture changes'
        }
    }
}
Assert ((Get-WalkDestination 988 12 988 $true 300) -eq 12) 'Right-edge walk stopped short'
Assert ((Get-WalkDestination 12 12 988 $true -300) -eq 988) 'Left-edge walk stopped short'
Assert ((Get-WalkDestination -1200 -1500 -300 $true 300) -eq -300) 'Negative-coordinate display crossing failed'
Assert ((Get-WalkDestination 20 12 10 $true 300) -eq 12) 'Narrow display destination escaped bounds'
foreach ($layout in @(@(0,0,1400,700),@(-1900,-100, -500,600),@(0,0,0,400))) {
 foreach ($shape in 0..2) {
  $route=New-ChaosRoute $layout[0] $layout[3] $layout[0] $layout[1] $layout[2] $layout[3] 232 $shape
  $first=Get-RoutePosition $route 0
  $last=Get-RoutePosition $route $route.length
  Assert ($first.x -eq $layout[0] -and $first.y -eq $layout[3]) 'Chaos route teleported at its start'
  Assert ($last.x -ge $layout[0]-0.01 -and $last.x -le $layout[2]+0.01 -and $last.y -ge $layout[1]-0.01 -and $last.y -le $layout[3]+0.01) 'Chaos route did not return to the screen'
  Assert ($route.points.Count -gt 5 -and $route.length -gt 0) 'Chaos route lost its rounded turns'
  $previous=$first; $outside=$false
  foreach ($step in 1..100) {
   $point=Get-RoutePosition $route ($route.length*$step/100)
   $jump=[Math]::Sqrt([Math]::Pow($point.x-$previous.x,2)+[Math]::Pow($point.y-$previous.y,2))
   Assert ($jump -le $route.length/100+0.01) 'Chaos route jumped at a corner'
   Assert ($point.y -ge $layout[1]-0.01 -and $point.y -le $layout[3]+0.01) 'Chaos route escaped vertically'
   if ($point.x -lt $layout[0] -or $point.x -gt $layout[2]) { $outside=$true }
   $previous=$point
  }
  if ($shape -eq 1) { Assert $outside 'Off-screen detour never left the screen' }
 }
}
$script:motion=$true; $script:mode=1; $script:auto=$true
$script:roamEnabled=$false; $script:quietUntil=0
$script:nextRest=0; $script:nextDrop=-1; $script:nextExpression=-2; $script:nextBack=-3
Assert ((Get-DueDetail 10) -eq 'back') 'Oldest detail was starved by fixed priority'
$script:quietUntil=200
Assert ((Get-DueDetail 20) -eq '') 'Overdue details ran back-to-back'
$script:quietUntil=0; $script:roamEnabled=$true; $script:nextRoam=0
Assert ((Get-DueDetail 10) -eq '') 'An overdue detail stole the automatic walk'
$script:mode=2
Assert (-not (Test-RoamDue 10)) 'Sleeping pet should not autonomously walk'
$script:nextCamera=5
foreach ($mode in @(0,1,3)) {
 $script:mode=$mode
 Assert ((Get-DueDetail 10) -eq 'camera') 'Overdue life action was starved by a posture restriction, rest or walk'
}
$script:mode=2
Assert ((Get-DueDetail 10) -ne 'camera') 'New life action woke the sleeping pet'
$script:mode=1; $script:quietUntil=20
Assert ((Get-DueDetail 10) -eq '') 'Life action interrupted the quiet hold'
$script:quietUntil=0; $script:rest=@{start=0;hold=150}
Assert ((Get-DueDetail 10) -eq '') 'Life action interrupted the long side rest'
$script:rest=$null; $script:pressed=$true
Assert ((Get-DueDetail 10) -eq '') 'Life action interrupted a held pet'
$script:pressed=$false; $script:auto=$false; $script:roamEnabled=$false
Assert ((Get-DueDetail 10) -ne 'camera') 'Life actions ignored manual activity selection'
$script:auto=$true
$previous=''
foreach ($cycle in 1..20) {
 $seen=New-Object 'System.Collections.Generic.HashSet[string]'
 foreach ($slot in 1..6) {
  $action=Get-NextLifeAction
  Assert ($action -ne $previous) 'Life action repeated across shuffle rounds'
  Assert ($seen.Add($action)) 'Life action bag repeated one gesture before showing the others'
  $previous=$action
 }
 Assert ($seen.Count -eq 6 -and $seen.Contains('potty') -and $seen.Contains('noodles') -and $seen.Contains('hairHeart')) 'A new activity was missing from the life rotation'
}
$script:nextCamera=$null
. (Join-Path $root 'Mischief.ps1')
$contexts=@('hello','gameStart','gameCheer','gameLoss','eatPoke','phonePoke','gamePoke','sleepPoke','lift','putDown','phoneDrop','walk','walkPoke','backPoke','playful')
foreach ($name in $contexts) {
    Assert ($null -ne $script:mischiefCatalog.contexts.PSObject.Properties[$name]) ('Missing dialogue context: '+$name)
}
foreach ($property in $script:mischiefCatalog.contexts.PSObject.Properties) {
    foreach ($line in $property.Value) {
        Assert (-not $line.Contains('줴줴') -or $property.Name -eq 'gameLoss') 'GG escaped the finished-game context'
        Assert (($line -notmatch '티~원|티워') -or $property.Name.StartsWith('game')) 'T1 escaped the game context'
    }
}
Set-MischiefLevel 'off' -NoSave
foreach ($name in $contexts) {
    $line=Get-MischiefLine $name 'plain' 10 0 0
    Assert ($line.text -eq 'plain' -and -not $line.isMeme) 'Off mode leaked a meme'
}
Set-MischiefLevel 'mild' -NoSave
Assert (-not (Get-MischiefLine 'lift' 'plain' 10 20 0).isMeme) 'Mild chance exceeded 20 percent'
$firstMild=Get-MischiefLine 'lift' 'plain' 10 19 0
Assert ($firstMild.isMeme -and $script:nextMemeAt -eq 130) 'Mild mode lost its two-minute cooldown'
Assert (-not (Get-MischiefLine 'gameLoss' 'plain' 129.9 0 0).isMeme) 'Cooldown was per-context instead of global'
$secondMild=Get-MischiefLine 'lift' 'plain' 130 0 0
Assert ($secondMild.isMeme -and $secondMild.text -ne $firstMild.text) 'Contextual dialogue immediately repeated'
Set-MischiefLevel 'normal' -NoSave
Assert (-not (Get-MischiefLine 'gameStart' 'plain' 20 60 0).isMeme) 'Normal chance exceeded 60 percent'
Assert (-not (Get-MischiefLine 'unknown' 'plain' 20 0 0).isMeme -and $script:nextMemeAt -eq 0) 'Unknown context consumed cooldown'
Assert ((Get-MischiefLine 'gameStart' 'plain' 20 59 0).isMeme -and $script:nextMemeAt -eq 50) 'Normal mode lost its cooldown'
Assert (-not (Get-MischiefLine 'phoneDrop' 'plain' 49.9 0 0).isMeme) 'Normal cooldown was ignored'
Assert ((Get-MischiefLine 'phoneDrop' 'plain' 50 0 0).isMeme) 'Normal cooldown did not expire'
$script:memeFaceEnd=10
Set-MischiefLevel 'off' -NoSave
Assert ($script:memeFaceEnd -eq 0 -and $script:nextMemeAt -eq 0) 'Disabling mischief did not clear the extra reaction'
# Use an isolated preferences file; never write the user's actual app settings.
$script:testMischiefPath=Join-Path ([IO.Path]::GetTempPath()) ('kikki-settings-'+[Guid]::NewGuid().ToString('N')+'/mischief.json')
function Get-MischiefSettingsPath { return $script:testMischiefPath }
try {
    Set-MischiefLevel 'mild'
    Set-MischiefLevel 'normal' -NoSave
    Read-MischiefSettings
    Assert ($script:mischiefLevel -eq 'mild') 'Saved mild mode did not survive a reload'
    Set-MischiefLevel 'off'
    Set-MischiefLevel 'normal' -NoSave
    Read-MischiefSettings
    Assert ($script:mischiefLevel -eq 'off') 'Saved off mode did not survive a reload'
    Set-Content -LiteralPath $script:testMischiefPath -Value 'broken json' -Encoding UTF8
    Read-MischiefSettings
    Assert ($script:mischiefLevel -eq 'normal') 'Damaged preferences did not fall back safely'
} finally { Remove-Item -LiteralPath (Split-Path $script:testMischiefPath -Parent) -Recurse -Force }
$files=Get-ChildItem $root -Filter '*.ps1' -File
foreach ($file in $files) {
    $tokens=$null; $errors=$null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName,[ref]$tokens,[ref]$errors)
    Assert ($errors.Count -eq 0) ('PowerShell syntax error: '+$file.Name+': '+($errors -join '; '))
}
Write-Output ('PASS: {0} runtime checks; event dispatch, disposal, scheduling, minute-scale behavior, contextual dialogue, PowerShell parsing. WPF UI requires Windows.' -f $checks)
