$script:previousReelsStyle=-1
$script:reelsNames=@('팔 흔들기','어깨 까딱','발 스텝','손하트')
function Get-NextReelsStyle {
 $choices=@(0..3 | Where-Object { $_ -ne $script:previousReelsStyle })
 $script:previousReelsStyle=$choices[$script:rng.Next($choices.Count)]
 return $script:previousReelsStyle
}
$reelsBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$reelsBitmap.BeginInit(); $reelsBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$reelsBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-reels-variety.png')
$reelsBitmap.EndInit(); $reelsBitmap.Freeze()
# Atlas cuts are set to the actual transparent gutters after generation.
$reelsFrames=@(); $reelsBounds=@()
for ($i=0;$i -lt 12;$i++) {
 $col=$i%4; $row=[int][Math]::Floor($i/4)
 $x0=[int][Math]::Floor($col*$reelsBitmap.PixelWidth/4); $x1=[int][Math]::Floor(($col+1)*$reelsBitmap.PixelWidth/4)
 $rowCuts=@(0,406,748,1086)
 $y0=$rowCuts[$row]; $y1=$rowCuts[$row+1]
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($reelsBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Reels atlas crop touches a character edge' }
 $reelsFrames+=$frame; $reelsBounds+=,$bounds
}
$reelsWidth=($reelsBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$reelsHeight=($reelsBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$reelsReference=Get-RestBounds $script:sprites[0]
$reelsFactor=[Math]::Min(($reelsReference[2]-$reelsReference[0]+1.0)/$reelsWidth,($reelsReference[3]-$reelsReference[1]+1.0)/$reelsHeight)
for ($i=0;$i -lt 12;$i++) {
 $frame=$reelsFrames[$i]; $bounds=$reelsBounds[$i]
 # The phone tripod is the leftmost part: anchor it and the floor instead of recentering every pose.
 $x=$reelsReference[0]-$bounds[0]*$reelsFactor
 $y=$reelsReference[3]-$bounds[3]*$reelsFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$reelsFactor,$frame.PixelHeight*$reelsFactor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:cameraSprites+=$image
}
