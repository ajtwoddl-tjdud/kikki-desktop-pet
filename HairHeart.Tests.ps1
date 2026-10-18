function Invoke-HairHeartSelfTest {
 $script:motion=$true; $script:pressed=$false; $script:dragging=$false
 Set-Pose 1 -Immediate
 Start-Pomodoro 25 5 2
 $deadline=$script:pomodoro.deadline
 $t=75000.0
 Start-CameraScene 'hairHeart' $t
 if ($script:cameraScene.duration -ne 5.6) { throw 'Hair heart did not reserve time for the pluck, shaping and presentation' }
 $seen=New-Object 'System.Collections.Generic.HashSet[int]'
 foreach ($phase in @(0.2,0.6,1.0,1.4,2.0,2.8)) {
  Render-CameraScene ($t+$phase*5.6/3.0)
  $frame=Get-HairHeartFrame $phase
  [void]$seen.Add($frame)
  if (-not [Object]::ReferenceEquals($script:pet.Source,$script:hairHeartSprites[$frame])) { throw 'Hair pluck/bending/heart/presentation/restoration frame missing' }
 }
 if ($seen.Count -ne 6) { throw 'Hair heart skipped part of its six-pose sequence' }
 if ($script:pomodoro.deadline -ne $deadline) { throw 'Hair heart reset the running Pomodoro' }
 Stop-Pomodoro -Quiet
 React-ToPoke ($t+1)
 if ($script:extraLines.hairHeartPoke -notcontains $script:words.Text -or $null -eq $script:cameraScene) { throw 'Touching hair heart used unrelated dialogue or cancelled the scene' }
 $script:motion=$false
 Render-CameraScene ($t+2)
 if (-not [Object]::ReferenceEquals($script:pet.Source,$script:hairHeartSprites[4])) { throw 'Reduced-motion hair heart still plucked or bent hair' }
 $script:motion=$true
 Render-CameraScene ($t+5.7)
 if ($null -ne $script:cameraScene -or $script:mode -ne 1 -or -not [Object]::ReferenceEquals($script:pet.Source,$script:sprites[1])) { throw 'Hair heart did not restore the original unmodified pet' }
 Start-CameraScene 'hairHeart' $t
 $script:dragging=$true; Render-CameraScene ($t+1)
 if ($null -ne $script:cameraScene) { throw 'Hair-heart pose remained over the lifted pet' }
 $script:dragging=$false
 Set-ChaosEnabled $true
 Start-ChaosAction 'hairHeart' $t
 if ($script:cameraScene.duration -ne 3 -or $script:chaosNext -ne $t+3) { throw 'Hair heart broke the three-second chaos interval' }
 Render-CameraScene ($t+3.1)
 if ($null -ne $script:cameraScene) { throw 'Chaos hair heart did not finish' }
 Set-ChaosEnabled $false -Quiet
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,696,464))
  foreach ($i in 0..5) { $ctx.DrawImage($script:hairHeartSprites[$i],[Windows.Rect]::new(($i%3)*232,[int][Math]::Floor($i/3)*232,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(696,464,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-hair-heart-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Set-Pose 1 -Immediate
 Write-Output 'PASS: six hair-heart poses; pluck/shaping/presentation/tuft restoration; quiet and chaos durations; touch, drag, reduced motion; running Pomodoro preserved.'
}
