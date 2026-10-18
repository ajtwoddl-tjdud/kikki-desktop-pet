$script:cymbalScene=$null
$script:pendingCymbals=$false
$script:cymbalSound=$true
$script:cymbalSignals=0
$script:cymbalTestRendering=$false
$script:cymbalMessage=''
$script:cymbalPlayer=New-Object System.Media.SoundPlayer (Join-Path $PSScriptRoot 'assets/kikki-cymbals.wav')
try { $script:cymbalPlayer.Load() } catch { $script:cymbalPlayer=$null }

$extraBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$extraBitmap.BeginInit(); $extraBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$extraBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-cymbals-stretch.png')
$extraBitmap.EndInit(); $extraBitmap.Freeze()
$extraFrames=@(); $extraBounds=@()
for ($i=0;$i -lt 8;$i++) {
 $col=$i%4; $row=[int][Math]::Floor($i/4)
 # Follow the generated atlas gutters rather than cutting through feet and cymbals.
 $columns=@(@(0,467,877,1284,1774),@(0,433,883,1352,1774))
 $rows=@(0,530,887)
 $x0=$columns[$row][$col]; $x1=$columns[$row][$col+1]
 $y0=$rows[$row]; $y1=$rows[$row+1]
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($extraBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Cymbal/stretch atlas crop touches a character edge' }
 $extraFrames+=$frame; $extraBounds+=,$bounds
}
$script:extraSprites=@()
for ($row=0;$row -lt 2;$row++) {
 $indices=($row*4)..($row*4+3)
 $width=($indices | ForEach-Object { $extraBounds[$_][2]-$extraBounds[$_][0]+1 } | Measure-Object -Maximum).Maximum
 $height=($indices | ForEach-Object { $extraBounds[$_][3]-$extraBounds[$_][1]+1 } | Measure-Object -Maximum).Maximum
 $reference=Get-RestBounds $script:sprites[@(0,2)[$row]]
 $factor=[Math]::Min(($reference[2]-$reference[0]+1.0)/$width,($reference[3]-$reference[1]+1.0)/$height)
 foreach ($i in $indices) {
  $frame=$extraFrames[$i]; $bounds=$extraBounds[$i]
  $x=($reference[0]+$reference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$factor
  $y=$reference[3]-$bounds[3]*$factor
  $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
  $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
  $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$factor,$frame.PixelHeight*$factor)); $ctx.Close()
  $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:extraSprites+=$image
 }
}
function Get-LyingStretchFrame([double]$age) {
 if ($age -lt 0.65) { return 4 }
 if ($age -lt 1.25) { return 5 }
 if ($age -lt 2.6) { return 6 }
 return 7
}
function Stop-Cymbals {
 $script:pendingCymbals=$false
 if ($null -ne $script:cymbalPlayer) { $script:cymbalPlayer.Stop() }
 if ($null -eq $script:cymbalScene) { return }
 $script:cymbalScene.clock.Stop()
 # Numeric scene clocks never advanced during the alarm. Keep the wall-clock activity deadline in step.
 $script:nextChange=$script:nextChange.AddSeconds($script:cymbalScene.clock.Elapsed.TotalSeconds)
 $script:cymbalScene=$null
 if ($script:window.IsVisible) { $script:clock.Start() }
}
function Try-StartCymbals {
 if (-not $script:pendingCymbals -or -not $script:window.IsVisible -or $script:pressed -or $script:dragging) { return }
 if ($SelfTest -and -not $script:cymbalTestRendering) { return }
 $message=$script:cymbalMessage
 if ($null -ne $script:cymbalScene) { Stop-Cymbals } else { $script:pendingCymbals=$false }
 $script:clock.Stop()
 $script:cymbalScene=@{clock=[Diagnostics.Stopwatch]::StartNew();previous=$script:pet.Source}
 $script:pendingPoke=$null
 if ($message -and $script:words.Text -ne $message) { Say $message; $script:bubbleUntil=[DateTime]::Now.AddSeconds(10) }
}
function Request-Cymbals([string]$Message=$script:words.Text) {
 Stop-Cymbals
 $script:cymbalMessage=$Message
 $script:cymbalSignals++
 $script:pendingCymbals=$true
 $script:pendingPoke=$null
 if (-not $SelfTest -and $script:cymbalSound -and $null -ne $script:cymbalPlayer) {
  try { $script:cymbalPlayer.Play() } catch { }
 }
 Try-StartCymbals
 if ($null -ne $script:timer) { Sync-PetTimers }
}
function Get-CymbalFrame([double]$age) {
 if ($age -lt 0.16) { return 0 }
 if ($age -ge 2.56) { return 3 }
 $phase=($age-0.16)%0.48
 if ($phase -lt 0.12) { return 1 }
 if ($phase -lt 0.24) { return 2 }
 return 3
}
function Render-Cymbals([double]$age=-1) {
 if ($null -eq $script:cymbalScene) { return }
 if ($age -lt 0) { $age=$script:cymbalScene.clock.Elapsed.TotalSeconds }
 if ($age -ge 2.9) { Stop-Cymbals; return }
 $index=if ($script:motion) { Get-CymbalFrame $age } else { 0 }
 $script:pet.Source=$script:extraSprites[$index]; $script:pet.Opacity=1
 $script:restBlend.Visibility='Hidden'; $script:sleepMark.Visibility='Hidden'; $script:fallingPhone.Visibility='Hidden'
 $tr=$script:pet.RenderTransform.Children
 $tr[0].ScaleX=1; $tr[0].ScaleY=1; $tr[1].Angle=0; $tr[2].X=0; $tr[2].Y=0; $tr[3].AngleX=0
 if ($script:motion) {
  $tr[1].Angle=2*[Math]::Sin($age*[Math]::PI/0.24)
  $tr[2].Y=-2*[Math]::Abs([Math]::Sin($age*[Math]::PI/0.48))
 }
 [Windows.Controls.Canvas]::SetTop($script:groundShadow,241)
 Update-BubblePosition
}
