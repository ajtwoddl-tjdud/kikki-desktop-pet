function Invoke-SmokingSelfTest {
 $script:motion=$true; $script:pressed=$false; $script:dragging=$false
 $script:pomodoro=$null; $script:pendingPoke=$null
 Set-Pose 1 -Immediate
 $t=70000.0
 Start-CameraScene 'smoke' $t
 if ($script:cameraScene.duration -ne 6.5) { throw 'Normal smoke scene did not use its quiet longer duration' }
 $seen=New-Object 'System.Collections.Generic.HashSet[int]'
 foreach ($phase in @(0.2,0.45,0.85,2.8)) {
  $age=$phase*6.5/3.0
  Render-CameraScene ($t+$age)
  $index=Get-SmokeFrame $phase
  [void]$seen.Add($index)
  if (-not [Object]::ReferenceEquals($script:pet.Source,$script:smokeSprites[$index])) { throw 'Smoke scene omitted hand raise, inhale, exhale or lowering' }
 }
 if ($seen.Count -ne 4) { throw 'Smoking animation reused one pose' }
 React-ToPoke ($t+1)
 if ($null -eq $script:cameraScene -or $script:extraLines.smokePoke -notcontains $script:words.Text) { throw 'Smoke click used unrelated dialogue or cancelled the puff' }
 $script:motion=$false
 Render-CameraScene ($t+3)
 if (-not [Object]::ReferenceEquals($script:pet.Source,$script:smokeSprites[0])) { throw 'Reduced motion kept puffing' }
 $script:motion=$true
 Render-CameraScene ($t+6.6)
 if ($null -ne $script:cameraScene -or $script:mode -ne 1) { throw 'Smoking did not restore the previous activity' }
 Start-CameraScene 'smoke' $t
 $script:dragging=$true
 Render-CameraScene ($t+1)
 if ($null -ne $script:cameraScene) { throw 'Smoking continued over a drag' }
 $script:dragging=$false
 Set-ChaosEnabled $true
 Start-ChaosAction 'smoke' $t
 if ($script:cameraScene.kind -ne 'smoke' -or $script:cameraScene.duration -ne 3 -or $script:chaosNext -ne $t+3) { throw 'Smoking slowed down chaos mode' }
 Render-CameraScene ($t+3.1)
 if ($null -ne $script:cameraScene) { throw 'Chaos smoking failed to finish in three seconds' }
 Set-ChaosEnabled $false -Quiet
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,928,232))
  foreach ($i in 0..3) { $ctx.DrawImage($script:smokeSprites[$i],[Windows.Rect]::new($i*232,0,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(928,232,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-smoking-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Set-Pose 1 -Immediate
 Write-Output 'PASS: four smoking poses; quiet and chaos timing; contextual click; reduced motion; drag cancellation and return to resting.'
}
