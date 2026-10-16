$script:lifted=$false
$script:liftStart=0.0
$script:sulkEnd=0.0
$script:dragOriginTop=0.0
$liftBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$liftBitmap.BeginInit()
$liftBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$liftBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-lift.png')
$liftBitmap.EndInit(); $liftBitmap.Freeze()
$script:liftSprites=@()
$reference=Get-RestBounds $script:sprites[0]
for ($i=0;$i -lt 4;$i++) {
 $col=$i%2; $row=[int][Math]::Floor($i/2)
 $x0=[int][Math]::Floor($col*$liftBitmap.PixelWidth/2); $x1=[int][Math]::Floor(($col+1)*$liftBitmap.PixelWidth/2)
 $y0=[int][Math]::Floor($row*$liftBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$liftBitmap.PixelHeight/2)
 if ($i -eq 3) { $y0+=18 } # Exclude a few pixels from the neighboring dangling foot.
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($liftBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 if ($i -eq 3) { $script:liftSprites+=(Align-RestFrame $frame $script:sprites[0]); continue }
 $bounds=Get-RestBounds $frame
 $factor=($reference[2]-$reference[0]+1.0)/($bounds[2]-$bounds[0]+1)
 $x=($reference[0]+$reference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$factor
 # Keep the head anchored while the legs wriggle underneath it.
 $y=$reference[1]-$bounds[1]*$factor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$factor,$frame.PixelHeight*$factor)); $ctx.Close()
 $group.ClipGeometry=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,627,627))
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:liftSprites+=$image
}
$liftCycleBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$liftCycleBitmap.BeginInit()
$liftCycleBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$liftCycleBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-lift-cycle.png')
$liftCycleBitmap.EndInit(); $liftCycleBitmap.Freeze()
$liftFrames=@(); $liftBounds=@()
for ($i=0;$i -lt 8;$i++) {
 $col=$i%4; $row=[int][Math]::Floor($i/4)
 # Use the transparent gutters: generated cells are not exactly equal in width.
 $cuts=@(0,462,887,1318,1774)
 $x0=[int][Math]::Floor($cuts[$col]*$liftCycleBitmap.PixelWidth/1774); $x1=[int][Math]::Floor($cuts[$col+1]*$liftCycleBitmap.PixelWidth/1774)
 $y0=[int][Math]::Floor($row*$liftCycleBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$liftCycleBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($liftCycleBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $liftFrames+=$frame; $liftBounds+=,(Get-RestBounds $frame)
}
$maxWidth=($liftBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$maxHeight=($liftBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
# One scale for the whole cycle, constrained by the longest extended leg.
$factor=[Math]::Min(($reference[2]-$reference[0]+1.0)/$maxWidth,(627-28-$reference[1])/$maxHeight)
$script:liftCycle=@()
for ($i=0;$i -lt 8;$i++) {
 $frame=$liftFrames[$i]; $bounds=$liftBounds[$i]
 $x=($reference[0]+$reference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$factor
 $y=$reference[1]-$bounds[1]*$factor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$factor,$frame.PixelHeight*$factor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:liftCycle+=$image
}
function Track-PetLift([double]$t) {
 if ($script:dragging -and -not $script:lifted -and $script:dragOriginTop-$script:window.Top -ge 14) {
  $script:lifted=$true; $script:liftStart=$t
  $script:dropStart=$null; $script:expressionEnd=0
  $script:attentionEnd=0
  Say-Random 'lift'
 }
}
function End-PetDrag([double]$t, [switch]$Cancel) {
 $moved=$script:dragging; $wasLifted=$script:lifted
 $script:pressed=$false; $script:dragging=$false; $script:lifted=$false
 $script:pet.ReleaseMouseCapture()
 if ($Cancel) { $script:sulkEnd=0; Keep-OnScreen; return }
 if ($moved) {
  Keep-OnScreen
  $script:homeX=$script:window.Left; $script:nextRoam=$t+120
  if ($wasLifted) {
   $script:sulkEnd=$t+1.8; $script:nextExpression=$t+180
   $script:nextDrop=$t+480; $script:nextRest=$t+120
   $script:quietUntil=$t+90
   Say-Random 'putDown'
  } else { Say-Random 'drag' }
 } else { React-ToPoke $t }
}
function Render-PetLift([double]$t) {
 if (-not ($script:dragging -and $script:lifted) -and $t -ge $script:sulkEnd) { return }
 $transforms=$script:pet.RenderTransform.Children
 $transforms[0].ScaleX=1; $transforms[0].ScaleY=1
 $transforms[1].Angle=0; $transforms[2].X=0; $transforms[2].Y=0; $transforms[3].AngleX=0
 $script:pet.Opacity=1
 $script:fallingPhone.Visibility='Hidden'; $script:restBlend.Visibility='Hidden'; $script:sleepMark.Visibility='Hidden'
 if ($script:dragging -and $script:lifted) {
  $age=$t-$script:liftStart
  $phase=($age/1.35+0.018*[Math]::Sin($age*1.7))%1
  $step=[int][Math]::Floor($phase*8)
  if (-not $script:motion) { $step=0 }
  $script:pet.Source=$script:liftCycle[$step]
  if ($script:motion) { $transforms[1].Angle=0.65*[Math]::Sin($age*3.1) }
  $script:groundShadow.Opacity=0
 } else {
  $script:pet.Source=$script:liftSprites[3]
  [Windows.Controls.Canvas]::SetTop($script:groundShadow,241)
  $script:groundShadow.Opacity=0.7
 }
}
