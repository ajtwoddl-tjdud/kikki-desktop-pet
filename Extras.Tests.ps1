function Invoke-ExtrasSelfTest {
 Stop-Pomodoro -Quiet
 $script:motion=$true; $script:roamEnabled=$false
 $script:cymbalTestRendering=$false
 $now=[DateTime]::UtcNow
 $signals=$script:cymbalSignals
 Start-Pomodoro 1 1 2 $now
 if ($script:cymbalSignals -ne $signals) { throw 'Starting a timer rang the cymbals' }
 Update-Pomodoro $now.AddSeconds(60)
 if ($script:cymbalSignals -ne $signals+1) { throw 'Focus end did not signal once' }
 Update-Pomodoro $now.AddSeconds(60)
 if ($script:cymbalSignals -ne $signals+1) { throw 'Focus end repeatedly rang the cymbals' }
 Update-Pomodoro $now.AddSeconds(120)
 if ($script:cymbalSignals -ne $signals+2) { throw 'Break end did not signal once' }
 Update-Pomodoro $now.AddSeconds(180)
 if ($script:cymbalSignals -ne $signals+3) { throw 'Final focus end did not signal once' }
 Start-Pomodoro 1 1 2 $now
 Update-Pomodoro $now.AddHours(3)
 if ($script:cymbalSignals -ne $signals+4) { throw 'Overdue phases queued several cymbal performances' }
 Start-Pomodoro 1 1 2 $now
 Toggle-PomodoroPause $now.AddSeconds(10)
 Update-Pomodoro $now.AddHours(3)
 Stop-Pomodoro -Quiet
 if ($script:cymbalSignals -ne $signals+4) { throw 'Pause or manual cancel rang the cymbals' }
 # A hidden deadline sounds once; the visual performance waits for the owner.
 $script:cymbalTestRendering=$true
 Set-Pose 1 -Immediate
 $t=$script:clock.Elapsed.TotalSeconds
 Start-Rest $t
 $restStart=$script:rest.start
 Start-Pomodoro 1 1 2 $now
 Toggle-PetVisibility
 Update-Pomodoro $now.AddSeconds(60)
 if (-not $script:pendingCymbals -or $null -ne $script:cymbalScene) { throw 'Hidden alarm opened an animation or lost its pending performance' }
 Toggle-PetVisibility
 if ($script:pendingCymbals -or $null -eq $script:cymbalScene -or $script:clock.IsRunning) { throw 'Showing the pet did not start cymbals while preserving normal scene time' }
 foreach ($age in @(0.05,0.20,0.30,0.46)) {
  Render-Cymbals $age
  if (-not [Object]::ReferenceEquals($pet.Source,$script:extraSprites[(Get-CymbalFrame $age)])) { throw 'Cymbal opening/clash/release frames were missing' }
 }
 $frozen=$script:clock.Elapsed.TotalSeconds
 Toggle-PetVisibility
 if ($script:cymbalScene.clock.IsRunning -or $script:timer.IsEnabled) { throw 'Hidden cymbals kept animating' }
 Toggle-PetVisibility
 if ($script:clock.IsRunning -or -not $script:cymbalScene.clock.IsRunning -or $script:clock.Elapsed.TotalSeconds -ne $frozen) { throw 'Showing cymbals advanced the resting scene' }
 Render-Cymbals 3.0
 if ($null -ne $script:cymbalScene -or -not $script:clock.IsRunning -or $script:rest.start -ne $restStart) { throw 'Cymbals failed to restore the long side rest' }
 Stop-Pomodoro -Quiet
 $script:cymbalTestRendering=$false
 # Stretch is a short detail inside the existing long rest, not a new activity.
 foreach ($mode in @(2)) {
  Set-Pose $mode -Immediate
  $t=40000.0
  Start-Rest $t
  $hold=$script:rest.hold; $deadline=$script:nextChange
  $script:rest.stretchAt=$t+50
  Update-Rest ($t+50)
  foreach ($age in @(0.3,0.9,1.8,3.1)) {
   Update-Rest ($t+50+$age)
   if (-not [Object]::ReferenceEquals($pet.Source,$script:extraSprites[(Get-LyingStretchFrame $age)])) { throw 'Lying stretch failed to extend and curl back' }
  }
  Update-Rest ($t+54)
  if ($null -eq $script:rest -or $null -ne $script:rest.stretchStart -or $script:rest.hold -ne $hold -or $script:mode -ne $mode -or $script:nextChange -ne $deadline) { throw 'Stretch shortened or replaced the long lying activity' }
  $expected=$script:restSprites[@(3,1)[$mode-1]]
  if (-not [Object]::ReferenceEquals($pet.Source,$expected)) { throw 'Stretch did not return to the side-lying pose' }
 }
 Set-Pose 1 -Immediate; Start-Rest $t
 $script:rest.stretchAt=$t+1
 Update-Rest ($t+2)
 if (-not [Object]::ReferenceEquals($pet.Source,$script:restSprites[3])) { throw 'Phone disappeared into a prop-free stretch pose' }
 $wav=[IO.File]::ReadAllBytes((Join-Path $PSScriptRoot 'assets/kikki-cymbals.wav'))
 if ([Text.Encoding]::ASCII.GetString($wav,0,4) -ne 'RIFF' -or [Text.Encoding]::ASCII.GetString($wav,8,4) -ne 'WAVE' -or $wav.Length -lt 200000) { throw 'Cymbal audio is not a complete PCM WAV' }
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,928,464))
  for ($i=0;$i -lt 8;$i++) { $ctx.DrawImage($script:extraSprites[$i],[Windows.Rect]::new(($i%4)*232,[int][Math]::Floor($i/4)*232,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(928,464,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-extras-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Stop-Rest $t
 Set-Pose 1 -Immediate
 Write-Output 'PASS: cymbals on focus/break/final completion; no duplicate, paused, cancelled or catch-up bursts; hidden deferral and frozen activity; lying stretch and return; PCM audio.'
}
