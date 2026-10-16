$script:rest=$null
$script:nextRest=110.0
Add-Type @'
public static class DoongiRestBounds {
 public static int[] Measure(byte[] p,int w,int h,int stride) {
  int l=w,t=h,r=0,b=0;
  for(int y=0;y<h;y++)for(int x=0;x<w;x++)if(p[y*stride+x*4+3]>32) {
   if(x<l)l=x; if(x>r)r=x; if(y<t)t=y; if(y>b)b=y;
  }
  return new int[]{l,t,r,b};
 }
}
'@
function Get-RestBounds($source) {
 $bitmap=[Windows.Media.Imaging.FormatConvertedBitmap]::new($source,[Windows.Media.PixelFormats]::Bgra32,$null,0)
 $stride=$bitmap.PixelWidth*4
 $pixels=New-Object byte[] ($stride*$bitmap.PixelHeight)
 $bitmap.CopyPixels($pixels,$stride,0)
 return ,([DoongiRestBounds]::Measure($pixels,$bitmap.PixelWidth,$bitmap.PixelHeight,$stride))
}
function Align-RestFrame($source,$reference) {
 $from=Get-RestBounds $source; $to=Get-RestBounds $reference
 $factor=($to[2]-$to[0]+1.0)/($from[2]-$from[0]+1)
 $x=($to[0]+$to[2])/2.0-($from[0]+$from[2])/2.0*$factor
 $y=$to[3]-$from[3]*$factor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($source,[Windows.Rect]::new($x,$y,$source.PixelWidth*$factor,$source.PixelHeight*$factor))
 $ctx.Close()
 $group.ClipGeometry=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,627,627))
 $result=[Windows.Media.DrawingImage]::new($group); $result.Freeze()
 return $result
}
$restBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$restBitmap.BeginInit()
$restBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$restBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-rest.png')
$restBitmap.EndInit(); $restBitmap.Freeze()
$script:restSprites=@()
for ($i=0;$i -lt 6;$i++) {
 $col=$i%3; $row=[int][Math]::Floor($i/3)
 $left=[int][Math]::Floor($col*$restBitmap.PixelWidth/3)
 $right=[int][Math]::Floor(($col+1)*$restBitmap.PixelWidth/3)
 $top=[int][Math]::Floor($row*$restBitmap.PixelHeight/2)
 $bottom=[int][Math]::Floor(($row+1)*$restBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($restBitmap,[Windows.Int32Rect]::new($left,$top,$right-$left,$bottom-$top))
 $referenceMode=@(2,2,1,1,0,0)[$i]
 $script:restSprites+=(Align-RestFrame $frame $script:sprites[$referenceMode])
}
$script:restBlend=$window.FindName('RestBlend')
$script:restBlend.RenderTransform=$script:pet.RenderTransform
function Stop-Rest([double]$t, [switch]$Completed) {
 $script:rest=$null
 if (-not $Completed) { $script:nextRest=$t+$script:rng.Next(120,181) }
 $script:restBlend.Visibility='Hidden'
 $script:pet.Opacity=1
}
function Start-Rest([double]$t) {
 if ($null -ne $script:poseTransition) { return }
 if ($null -ne $script:backTurn) { return }
 if (-not $script:motion -or $null -ne $script:rest -or $null -ne $script:roam -or $null -ne $script:dropStart -or $script:pressed -or $script:dragging -or $t -lt $script:attentionEnd) { return }
 $first=@(4,2,0,0)[$script:mode]; $hold=@(4.0,25.0,90.0,4.0)[$script:mode]
 $script:rest=@{start=$t;mode=$script:mode;first=$first;hold=$hold;stage=-1;lastSource=$script:pet.Source;previous=$script:pet.Source;changed=$t}
 # Count from the last small action, not after its long-held pose finishes.
 $script:nextRest=$t+$script:rng.Next(120,181)
 if ($script:mode -eq 3) {
  $script:rest.gameSource=if ($script:rng.Next(3) -eq 0) { $script:playfulSprites[3] } else { $script:lookSprites[3] }
 }
 $script:expressionEnd=0
 $script:nextExpression=[Math]::Max($script:nextExpression,$t+$hold+70)
 $script:nextDrop=[Math]::Max($script:nextDrop,$t+$hold+70)
 $script:quietUntil=$t+$hold+70
 if ($script:nextChange -lt [DateTime]::Now.AddSeconds($hold+2)) { $script:nextChange=[DateTime]::Now.AddSeconds($hold+2) }
}
function Update-Rest([double]$t) {
 if ($null -eq $script:rest) {
  if ($t -ge $script:quietUntil -and $t -ge $script:nextRest -and -not $SelfTest -and -not $script:pet.ContextMenu.IsOpen) { Start-Rest $t }
  if ($null -eq $script:rest) { return }
 }
 if (-not $script:motion -or $script:rest.mode -ne $script:mode -or $null -ne $script:roam -or $null -ne $script:dropStart -or $script:pressed -or $script:dragging -or $t -lt $script:attentionEnd) { Stop-Rest $t; return }
 $age=$t-$script:rest.start
 if ($age -ge $script:rest.hold+0.3) { Stop-Rest $t -Completed; return }
 $stage=if ($age -lt 0.9) { 0 } elseif ($age -lt $script:rest.hold) { 1 } else { 2 }
 $target=if ($stage -eq 2) { $script:sprites[$script:mode] } else { $script:restSprites[$script:rest.first+$stage] }
 if ($script:mode -eq 3 -and $stage -ne 2) { $target=$script:rest.gameSource }
 if ($stage -ne $script:rest.stage) {
  $script:rest.previous=$script:rest.lastSource; $script:rest.stage=$stage; $script:rest.changed=$t
 }
 $script:rest.lastSource=$target; $script:pet.Source=$target
 $blend=[Math]::Min(1.0,($t-$script:rest.changed)/0.24)
 $script:restBlend.Source=$script:rest.previous; $script:restBlend.Opacity=1-$blend
 $script:restBlend.Visibility=if ($blend -lt 1) { 'Visible' } else { 'Hidden' }
 $script:pet.Opacity=$blend
 $transforms=$script:pet.RenderTransform.Children
 $transforms[0].ScaleX=1; $transforms[0].ScaleY=1+0.003*[Math]::Sin($t*1.1)
 $transforms[1].Angle=0; $transforms[2].X=0; $transforms[2].Y=0; $transforms[3].AngleX=0
 if ($script:mode -eq 3) {
  $shift=[Math]::Sin([Math]::Min(1.0,$age/$script:rest.hold)*[Math]::PI)
  $transforms[1].Angle=0.7*$shift; $transforms[2].X=0.8*$shift
 }
}
