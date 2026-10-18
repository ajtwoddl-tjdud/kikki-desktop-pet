function Invoke-ReelsSelfTest {
 $script:previousReelsStyle=-1
 $seen=New-Object 'System.Collections.Generic.HashSet[int]'
 $last=-1
 for ($i=0;$i -lt 100;$i++) {
  $style=Get-NextReelsStyle
  if ($style -eq $last -or $style -lt 0 -or $style -gt 3) { throw 'Reels style repeated immediately or escaped its range' }
  [void]$seen.Add($style); $last=$style
 }
 if ($seen.Count -ne 4) { throw 'Random reels never selected every routine' }
 if ($script:cameraSprites.Count -ne 20) { throw 'Reels variety frames were not loaded' }
 $script:motion=$true; $script:pressed=$false; $script:dragging=$false
 foreach ($style in 0..3) {
  Set-Pose 1 -Immediate
  $t=60000+$style*10
  Start-CameraScene 'reels' $t $style
  $frames=New-Object 'System.Collections.Generic.HashSet[int]'
  $beat=@(0.28,0.34,0.22,0.6)[$style]
  foreach ($age in @(0.2,0.41,(0.41+$beat),1.4,2.6)) {
   Render-CameraScene ($t+$age)
   $index=Get-CameraFrame 'reels' $age $style
   if ($index -lt 4+$style*4 -or $index -gt 7+$style*4) { throw 'Reels used another routine mid-scene' }
   if (-not [Object]::ReferenceEquals($script:pet.Source,$script:cameraSprites[$index])) { throw 'Reels rendered the wrong arm or leg pose' }
   [void]$frames.Add($index)
  }
  if ($frames.Count -ne 4) { throw 'Reels routine omitted its ready/dance/ending poses' }
  $script:motion=$false
  Render-CameraScene ($t+1)
  if (-not [Object]::ReferenceEquals($script:pet.Source,$script:cameraSprites[4+$style*4]) -or $pet.RenderTransform.Children[2].Y -ne 0) { throw 'Reduced motion still danced' }
  $script:motion=$true
  Render-CameraScene ($t+3.1)
  if ($null -ne $script:cameraScene -or $script:mode -ne 1) { throw 'Reels variety failed to resume its original activity' }
 }
 Start-CameraScene 'selfie' 61000
 foreach ($age in @(0.2,0.7,1.4,2.6)) {
  if ((Get-CameraFrame 'selfie' $age 3) -gt 3) { throw 'Reels selection changed selfie frames' }
 }
 Set-Pose 1 -Immediate
 if ($env:KIKKI_PREVIEW_DIR) {
  $visual=[Windows.Media.DrawingVisual]::new(); $ctx=$visual.RenderOpen()
  $ctx.DrawRectangle([Windows.Media.Brushes]::White,$null,[Windows.Rect]::new(0,0,928,928))
  for ($i=0;$i -lt 16;$i++) { $ctx.DrawImage($script:cameraSprites[$i+4],[Windows.Rect]::new(($i%4)*232,[int][Math]::Floor($i/4)*232,232,232)) }
  $ctx.Close()
  $bitmap=[Windows.Media.Imaging.RenderTargetBitmap]::new(928,928,96,96,[Windows.Media.PixelFormats]::Pbgra32); $bitmap.Render($visual)
  $encoder=[Windows.Media.Imaging.PngBitmapEncoder]::new(); $encoder.Frames.Add([Windows.Media.Imaging.BitmapFrame]::Create($bitmap))
  $stream=[IO.File]::Create((Join-Path $env:KIKKI_PREVIEW_DIR 'kikki-reels-preview.png'))
  try { $encoder.Save($stream) } finally { $stream.Dispose() }
 }
 Write-Output 'PASS: four randomly selected reels without immediate repeats; distinct ready/dance/ending poses; different rhythms; reduced motion; original activity and selfie preserved.'
}
