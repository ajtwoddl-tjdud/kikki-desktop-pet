function Invoke-NoodlesSelfTest {
 $script:motion=$true; $script:pressed=$false; $script:dragging=$false
 Set-Pose 1 -Immediate
 Start-Pomodoro 25 5 2
 $deadline=$script:pomodoro.deadline
 $t=75000.0
 Start-CameraScene 'noodles' $t
 if ($script:cameraScene.duration -ne 10.0) { throw 'Spicy noodles did not reserve time for the slurping, heat, fanning and drinking' }
 $seen=New-Object 'System.Collections.Generic.HashSet[int]'
 foreach ($phase in @(0.2,0.6,1.1,1.6,2.3,2.8)) {
  Render-CameraScene ($t+$phase*10.0/3.0)
  $frame=Get-NoodlesFrame $phase
  [void]$seen.Add($frame)
  if (-not [Object]::ReferenceEquals($script:pet.Source,$script:noodlesSprites[$frame])) { throw 'Noodle slurp/heat/fanning/reach/drink frame missing' }
 }
 if ($seen.Count -ne 6) { throw 'Spicy noodles skipped part of its six-pose sequence' }
 if ($script:pomodoro.deadline -ne $deadline) { throw 'Spicy noodles reset the running Pomodoro' }
 Stop-Pomodoro -Quiet
 React-ToPoke ($t+1)
 if ($script:extraLines.noodlesEatPoke -notcontains $script:words.Text -or $null -eq $script:cameraScene) { throw 'Touching spicy noodles used unrelated dialogue or cancelled the scene' }
 $script:motion=$false
 Render-CameraScene ($t+2)
 if (-not [Object]::ReferenceEquals($script:pet.Source,$script:noodlesSprites[0])) { throw 'Reduced-motion spicy noodles kept changing poses' }
 $script:motion=$true
 Render-CameraScene ($t+10.1)
 if ($null -ne $script:cameraScene -or $script:mode -ne 1 -or -not [Object]::ReferenceEquals($script:pet.Source,$script:sprites[1])) { throw 'Spicy noodles did not restore the original unmodified pet' }
 Start-CameraScene 'noodles' $t
 $script:dragging=$true; Render-CameraScene ($t+1)
 if ($null -ne $script:cameraScene) { throw 'Spicy-noodle pose remained over the lifted pet' }
 $script:dragging=$false
 foreach ($sample in @(@(0.5,'noodlesEatPoke'),@(4.0,'noodlesHotPoke'),@(8.6,'noodlesWaterPoke'))) {
  Start-CameraScene 'noodles' $t
  React-ToPoke ($t+$sample[0])
  if ($script:extraLines[$sample[1]] -notcontains $script:words.Text) { throw 'Noodle reply did not match eating, heat or drinking' }
 }
 Start-CameraScene 'noodles' $t
 $script:attentionEnd=0
 Render-CameraScene ($t+3.3)
 if ($script:words.Text -ne '아 안 매운 줄.') { throw 'Heat reaction was missing' }
 $script:words.Text='one-shot heat marker'
 Render-CameraScene ($t+4.5)
 if ($script:words.Text -ne 'one-shot heat marker') { throw 'Heat line repeated on every render' }
 Start-Pomodoro 25 5 2
 Start-CameraScene 'noodles' $t
 React-ToPoke ($t+3.0)
 $timerReply=$script:words.Text; $pendingReply=$script:pendingPoke
 Render-CameraScene ($t+3.3)
 if ($null -eq $pendingReply -or $script:words.Text -ne $timerReply -or -not [Object]::ReferenceEquals($script:pendingPoke,$pendingReply)) { throw 'Heat reaction overwrote the timer-first click reply' }
 Stop-Pomodoro -Quiet
 Set-ChaosEnabled $true
 Start-ChaosAction 'noodles' $t
 if ($script:cameraScene.duration -ne 3 -or $script:chaosNext -ne $t+3) { throw 'Spicy noodles broke the three-second chaos interval' }
 Render-CameraScene ($t+3.1)
 if ($null -ne $script:cameraScene) { throw 'Chaos spicy noodles did not finish' }
 Set-ChaosEnabled $false -Quiet
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,696,464))
  foreach ($i in 0..5) { $ctx.DrawImage($script:noodlesSprites[$i],[Windows.Rect]::new(($i%3)*232,[int][Math]::Floor($i/3)*232,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(696,464,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-spicy-noodles-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Set-Pose 1 -Immediate
 Write-Output 'PASS: six noodle/slurp/heat/fanning/reach/drink poses; contextual clicks and one-shot heat speech; timer-first reply and deadline preserved; quiet/chaos durations; drag cancellation, reduced motion and activity return.'
}
