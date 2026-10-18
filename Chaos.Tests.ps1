function Invoke-ChaosSelfTest {
 $script:pomodoro=$null; $script:pendingPoke=$null
 $script:rng=[Random]::new(1907)
 $seen=New-Object 'System.Collections.Generic.HashSet[string]'
 $last=''
 for ($i=0;$i -lt 200;$i++) {
  $action=Get-NextChaosAction
  if ($action -eq $last) { throw 'Chaos immediately repeated the same action' }
  [void]$seen.Add($action); $last=$action
 }
 if ($seen.Count -ne 9) { throw 'Random chaos omitted an action' }
 Set-Pose 1 -Immediate
 $script:auto=$true; $script:motion=$false; $script:roamEnabled=$false
 Set-ChaosEnabled $true
 if (-not $script:chaosEnabled -or -not $script:motion -or $script:auto) { throw 'Chaos did not start independently of normal settings' }
 if ((Get-DueDetail 99999) -ne '' -or (Test-RoamDue 99999)) { throw 'Normal schedules interrupted chaos' }
 $area=[Windows.SystemParameters]::WorkArea
 $script:window.Left=$area.Left+12
 $t=20000.0
 foreach ($action in @('selfie','reels','smoke','banana','phone','sleep','game','drop','run')) {
  Start-ChaosAction $action $t
  if ($script:chaosNext -ne $t+3) { throw 'Chaos action did not use a three-second deadline' }
  if ($action -in @('selfie','reels','smoke')) {
   $frames=New-Object 'System.Collections.Generic.HashSet[int]'
   foreach ($age in @(0.2,0.7,1.4,2.8)) {
    $index=Get-CameraFrame $action $age $script:cameraScene.style
    [void]$frames.Add($index)
    Animate-Pet ($t+$age); Render-CameraScene ($t+$age)
    $expected=if ($action -eq 'smoke') {$script:smokeSprites[$index]} else {$script:cameraSprites[$index]}
    if (-not [Object]::ReferenceEquals($script:pet.Source,$expected)) { throw "Camera did not render its actual pose: $action at $age" }
   }
   if ($frames.Count -lt 3) { throw 'Camera sequence lacked pose changes' }
  }
  if ($action -eq 'drop') {
   foreach ($sample in @(@(0.4,0),@(0.6,2),@(1.0,3))) {
    Animate-Pet ($t+$sample[0])
    if (-not [Object]::ReferenceEquals($script:pet.Source,$script:dropSprites[$sample[1]])) { throw 'Fast drop skipped falling/impact/reaction' }
   }
   foreach ($age in @(1.75,2.0,2.25,2.6)) {
    Animate-Pet ($t+$age)
    if ($script:fallingPhone.Visibility -ne 'Hidden') { throw 'Fast pickup left a floating phone' }
   }
   Animate-Pet ($t+2.9)
   if ($null -ne $script:dropStart) { throw 'Chaos phone pickup exceeded three seconds' }
  }
  if ($action -eq 'run') {
   if ($null -eq $script:roam) { throw 'Chaos never started a crossing' }
   $target=$script:roam.toX; $start=$script:window.Left
   Update-Roam ($t+1.5)
   if ($script:window.Left -eq $start -or $script:window.Left -eq $target) { throw 'Crossing teleported instead of walking' }
   Update-Roam ($t+3)
   if ([Math]::Abs($script:window.Left-$target) -gt 0.01) { throw 'Chaos did not reach the screen edge' }
  }
  $t+=10
 }
 $script:pressed=$true; $script:chaosNext=$t
 Update-Chaos ($t+10)
 if ($script:chaosNext -le $t+10) { throw 'Chaos kept a backlog while held' }
 $script:pressed=$false
 Start-ChaosAction 'sleep' $t
 Start-PostureTransition 0 2 $t $script:sprites[0]
 Render-PostureTransition ($t+0.2)
 if ($null -eq $script:poseTransition) { throw 'Chaos skipped the lying-down transition entirely' }
 Render-PostureTransition ($t+1.2)
 if ($null -ne $script:poseTransition) { throw 'Chaos transition was too slow for its action slot' }
 Start-ChaosAction 'selfie' $t
 $deadline=$script:chaosNext
 $clockTime=$script:clock.Elapsed.TotalSeconds
 Toggle-PetVisibility
 if ($script:timer.IsEnabled -or $script:clock.IsRunning) { throw 'Hidden chaos kept animating' }
 Toggle-PetVisibility
 if ($script:chaosNext -ne $deadline -or [Math]::Abs($script:clock.Elapsed.TotalSeconds-$clockTime) -gt 1) { throw 'Hidden chaos built up elapsed actions' }
 Set-ChaosEnabled $false -Quiet
 if ($script:chaosEnabled -or $script:motion -or -not $script:auto -or $script:roamEnabled -or $script:mode -ne 1) { throw 'Leaving chaos did not restore normal settings' }
 if ($null -ne $script:cameraScene -or $null -ne $script:roam -or $null -ne $script:dropStart) { throw 'Chaos left a scene running after exit' }
 $script:motion=$true
 Set-Pose 1 -Immediate
 Start-CameraScene 'selfie' $t
 Render-CameraScene ($t+3.1)
 if ($null -ne $script:cameraScene -or $script:mode -ne 1) { throw 'Standalone selfie did not return to the original activity' }
 Set-Pose 0 -Immediate
 React-ToPoke $t; React-ToPoke ($t+0.3); React-ToPoke ($t+0.6)
 if ($null -eq $script:pokeScene -or $script:extraLines.repeatPoke -notcontains $script:words.Text) { throw 'Repeated pokes never changed the reaction' }
 $firstKind=$script:pokeScene.kind
 React-ToPoke ($t+0.9)
 if ($script:pokeScene.kind -eq $firstKind) { throw 'Repeated pokes reused the same motion' }
 Render-RepeatPoke ($t+3)
 if ($null -ne $script:pokeScene) { throw 'Repeated poke motion never settled' }
 Set-Pose 2 -Immediate
 React-ToPoke $t; React-ToPoke ($t+0.3); React-ToPoke ($t+0.6)
 if ($null -ne $script:pokeScene -or $script:mode -ne 2) { throw 'Repeated pokes turned sleep into a different activity' }
 Set-Pose 1 -Immediate
 # Optional contact sheet uses the actual WPF sprites, including their normalization.
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,928,540))
  for ($i=0;$i -lt 8;$i++) { $ctx.DrawImage($script:cameraSprites[$i],[Windows.Rect]::new(($i%4)*232,[int][Math]::Floor($i/4)*270,232,232)) }
  $ctx.Close()
  $render=[Windows.Media.Imaging.RenderTargetBitmap]::new(928,540,96,96,[Windows.Media.PixelFormats]::Pbgra32)
  $render.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($render))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-camera-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Write-Output 'PASS: random non-repeating chaos; all nine actions; three-second crossing and complete phone pickup; camera/smoke frames; interruption; settings restoration; repeated poke variety.'
}
