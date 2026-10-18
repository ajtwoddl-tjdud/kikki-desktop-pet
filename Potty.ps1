$pottyBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$pottyBitmap.BeginInit(); $pottyBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$pottyBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-potty.png')
$pottyBitmap.EndInit(); $pottyBitmap.Freeze()
$script:extraLines.potty=@('잠깐. 저쪽 쫌 봐.','나 쫌 바빠.','잠깐만. 오지 마.')
$script:extraLines.pottyPoke=@('저쪽 봐.','아 쫌. 지금은 말고.','이건 구경 안 해도 돼.','눈 마주치지 말자.')
$pottyFrames=@(); $pottyBounds=@()
for ($i=0;$i -lt 6;$i++) {
 $col=$i%3; $row=[int][Math]::Floor($i/3)
 $x0=[int][Math]::Floor($col*$pottyBitmap.PixelWidth/3); $x1=[int][Math]::Floor(($col+1)*$pottyBitmap.PixelWidth/3)
 $y0=[int][Math]::Floor($row*$pottyBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$pottyBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($pottyBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Potty atlas crop touches a character edge' }
 $pottyFrames+=$frame; $pottyBounds+=,$bounds
}
$pottyWidth=($pottyBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$pottyHeight=($pottyBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$pottyReference=Get-RestBounds $script:sprites[0]
$pottyFactor=[Math]::Min(($pottyReference[2]-$pottyReference[0]+1.0)/$pottyWidth,($pottyReference[3]-$pottyReference[1]+1.0)/$pottyHeight)
$script:pottySprites=@()
for ($i=0;$i -lt 6;$i++) {
 $frame=$pottyFrames[$i]; $bounds=$pottyBounds[$i]
 $x=($pottyReference[0]+$pottyReference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$pottyFactor
 $y=$pottyReference[3]-$bounds[3]*$pottyFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$pottyFactor,$frame.PixelHeight*$pottyFactor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:pottySprites+=$image
}
function Get-PottyFrame([double]$age) {
 if ($age -lt 0.35) { return 0 }
 if ($age -lt 0.7) { return 1 }
 if ($age -lt 1.5) { return 2 }
 if ($age -lt 2.05) { return 3 }
 if ($age -lt 2.65) { return 4 }
 return 5
}
