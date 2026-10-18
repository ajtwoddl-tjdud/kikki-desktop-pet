function Invoke-PottySelfTest {
 $script:motion=$true; $script:pressed=$false; $script:dragging=$false
 Set-Pose 1 -Immediate
 Start-Pomodoro 25 5 2
 $deadline=$script:pomodoro.deadline
 $t=75000.0
 Start-CameraScene 'potty' $t
 if ($script:cameraScene.duration -ne 8.0) { throw 'Potty did not reserve time for squatting, straining and cleanup' }
 $seen=New-Object 'System.Collections.Generic.HashSet[int]'
 foreach ($phase in @(0.2,0.5,1.0,1.7,2.3,2.8)) {
  Render-CameraScene ($t+$phase*8.0/3.0)
  $frame=Get-PottyFrame $phase
  [void]$seen.Add($frame)
  if (-not [Object]::ReferenceEquals($script:pet.Source,$script:pottySprites[$frame])) { throw 'Potty squat/strain/glance/tissue/cleanup pose missing' }
 }
 if ($seen.Count -ne 6) { throw 'Potty skipped part of its six-pose sequence' }
 if ($script:pomodoro.deadline -ne $deadline) { throw 'Potty reset the running Pomodoro' }
 Stop-Pomodoro -Quiet
 React-ToPoke ($t+1)
 if ($script:extraLines.pottyPoke -notcontains $script:words.Text -or $null -eq $script:cameraScene) { throw 'Touching potty used unrelated dialogue or cancelled the scene' }
 $script:motion=$false
 Render-CameraScene ($t+2)
 if (-not [Object]::ReferenceEquals($script:pet.Source,$script:pottySprites[1])) { throw 'Reduced-motion potty kept changing poses' }
 $script:motion=$true
 Render-CameraScene ($t+8.1)
 if ($null -ne $script:cameraScene -or $script:mode -ne 1 -or -not [Object]::ReferenceEquals($script:pet.Source,$script:sprites[1])) { throw 'Potty did not restore the original unmodified pet' }
 Start-CameraScene 'potty' $t
 $script:dragging=$true; Render-CameraScene ($t+1)
 if ($null -ne $script:cameraScene) { throw 'Potty pose remained over the lifted pet' }
 $script:dragging=$false
 Set-ChaosEnabled $true
 Start-ChaosAction 'potty' $t
 if ($script:cameraScene.duration -ne 3 -or $script:chaosNext -ne $t+3) { throw 'Potty broke the three-second chaos interval' }
 Render-CameraScene ($t+3.1)
 if ($null -ne $script:cameraScene) { throw 'Chaos potty did not finish' }
 Set-ChaosEnabled $false -Quiet
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,696,464))
  foreach ($i in 0..5) { $ctx.DrawImage($script:pottySprites[$i],[Windows.Rect]::new(($i%3)*232,[int][Math]::Floor($i/3)*232,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(696,464,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-potty-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Set-Pose 1 -Immediate
 Write-Output 'PASS: six potty poses; squat/strain/embarrassed glance/tissue cleanup; quiet and chaos durations; touch, drag, reduced motion; running Pomodoro preserved.'
}
