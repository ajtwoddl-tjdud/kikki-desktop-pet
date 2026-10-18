$script:extraLines.smoke=@('후…','잠깐. 한 모금만.','여기 쫌 앉아 있을게.','아. 멍 쫌 때리고.')
$script:extraLines.smokePoke=@('왜. 뭐 할 말 있어?','잠깐. 후—.','아 쫌. 얼굴 앞에 오지 마.','왜. 연기 신기해?')
$smokeBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$smokeBitmap.BeginInit(); $smokeBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$smokeBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-smoking.png')
$smokeBitmap.EndInit(); $smokeBitmap.Freeze()
$smokeFrames=@(); $smokeBounds=@()
for ($i=0;$i -lt 4;$i++) {
 $col=$i%2; $row=[int][Math]::Floor($i/2)
 $x0=[int][Math]::Floor($col*$smokeBitmap.PixelWidth/2); $x1=[int][Math]::Floor(($col+1)*$smokeBitmap.PixelWidth/2)
 $y0=[int][Math]::Floor($row*$smokeBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$smokeBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($smokeBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Smoking atlas crop touches a character edge' }
 $smokeFrames+=$frame; $smokeBounds+=,$bounds
}
$smokeWidth=($smokeBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$smokeHeight=($smokeBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$smokeReference=Get-RestBounds $script:sprites[0]
$smokeFactor=[Math]::Min(($smokeReference[2]-$smokeReference[0]+1.0)/$smokeWidth,($smokeReference[3]-$smokeReference[1]+1.0)/$smokeHeight)
$script:smokeSprites=@()
for ($i=0;$i -lt 4;$i++) {
 $frame=$smokeFrames[$i]; $bounds=$smokeBounds[$i]
 $x=($smokeReference[0]+$smokeReference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$smokeFactor
 $y=$smokeReference[3]-$bounds[3]*$smokeFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$smokeFactor,$frame.PixelHeight*$smokeFactor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:smokeSprites+=$image
}
function Get-SmokeFrame([double]$age) {
 if ($age -lt 0.35) { return 0 }
 if ($age -ge 2.6) { return 3 }
 $phase=($age-0.35)%0.75
 if ($phase -lt 0.32) { return 1 }
 return 2
}
