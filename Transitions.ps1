$script:poseTransition=$null
$transitionBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$transitionBitmap.BeginInit()
$transitionBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$transitionBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-posture-transitions.png')
$transitionBitmap.EndInit(); $transitionBitmap.Freeze()
$transitionFrames=@(); $transitionBounds=@()
for ($i=0;$i -lt 12;$i++) {
 $col=$i%4; $row=[int][Math]::Floor($i/4)
 # Follow the actual transparent gutters, including the taller seated row.
 $rowCuts=@(0,436,770,1086)
 $columnCuts=@(@(0,344,693,1062,1448),@(0,368,729,1092,1448),@(0,378,724,1086,1448))
 $x0=$columnCuts[$row][$col]; $x1=$columnCuts[$row][$col+1]
 $y0=$rowCuts[$row]; $y1=$rowCuts[$row+1]
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($transitionBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $transitionFrames+=$frame; $transitionBounds+=,(Get-RestBounds $frame)
}
$width=($transitionBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$height=($transitionBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$ref=Get-RestBounds $script:sprites[0]
$factor=[Math]::Min(($ref[2]-$ref[0]+1.0)/$width,($ref[3]-$ref[1]+1.0)/$height)
$script:transitionSprites=@()
for ($i=0;$i -lt 12;$i++) {
 $frame=$transitionFrames[$i]
 $x=($ref[0]+$ref[2])/2.0-($transitionBounds[$i][0]+$transitionBounds[$i][2])/2.0*$factor
 $y=$ref[3]-$transitionBounds[$i][3]*$factor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$factor,$frame.PixelHeight*$factor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:transitionSprites+=$image
}
function Get-PostureRoute([int]$from,[int]$to) {
 if ($from -eq $to) { return @() }
 if ($from -eq 2 -and $to -eq 1) { return @(11,10,9,8,7,4,5) }
 if ($from -eq 1 -and $to -eq 2) { return @(5,6,7,8,9,10,11) }
 if ($from -eq 2) { return @(11,10,9,8,7,4,3,2,1,0) }
 if ($to -eq 2) { return @(0,1,2,3,4,7,8,9,10,11) }
 if ($from -eq 1) { return @(5,6,4,3,2,1,0) }
 if ($to -eq 1) { return @(0,1,2,3,4,5) }
 return @()
}
function Start-PostureTransition([int]$from,[int]$to,[double]$t,$previous) {
 if (-not $script:motion -or $null -eq $previous) { return }
 $route=@(Get-PostureRoute $from $to)
 if ($route.Count -eq 0) { return }
 $script:poseTransition=@{start=$t;route=$route;previous=$previous;target=$script:sprites[$to];duration=$route.Count*0.22+0.3}
 $script:quietUntil=$t+$script:poseTransition.duration+30
}
function Render-PostureTransition([double]$t) {
 if ($null -eq $script:poseTransition) { return }
 if (-not $script:motion -or $script:pressed -or $script:dragging) { $script:poseTransition=$null; return }
 $scene=$script:poseTransition; $age=[Math]::Max(0.0,$t-$scene.start)
 if ($age -ge $scene.duration) { $script:poseTransition=$null; return }
 $frameTime=$scene.route.Count*0.22
 $index=[Math]::Min($scene.route.Count-1,[int][Math]::Floor($age/0.22))
 $script:pet.Source=$script:transitionSprites[$scene.route[$index]]
 $script:pet.Opacity=1
 if ($age -lt 0.15) {
  $script:restBlend.Source=$scene.previous; $script:restBlend.Opacity=1-$age/0.15
  $script:restBlend.Visibility='Visible'; $script:pet.Opacity=$age/0.15
 } elseif ($age -ge $frameTime) {
  $p=($age-$frameTime)/0.3
  $script:restBlend.Source=$script:pet.Source; $script:restBlend.Opacity=1-$p
  $script:restBlend.Visibility='Visible'; $script:pet.Source=$scene.target; $script:pet.Opacity=$p
 }
 $tr=$script:pet.RenderTransform.Children
 $tr[0].ScaleX=1; $tr[0].ScaleY=1; $tr[1].Angle=0; $tr[2].X=0; $tr[2].Y=0; $tr[3].AngleX=0
 $script:sleepMark.Visibility='Hidden'; $script:fallingPhone.Visibility='Hidden'
 [Windows.Controls.Canvas]::SetTop($script:groundShadow,241)
 $script:groundShadow.Opacity=0.7
}
