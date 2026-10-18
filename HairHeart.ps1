$script:extraLines.hairHeart=@('잠깐. 하나만 뽑고.','이거 쫌 봐봐.','나 뭐 하나 해줄게.','잠깐만. 보고 있어.')
$script:extraLines.hairHeartPoke=@('아 언제부터 봤어.','왜. 기다려봐.','아 쫌. 손 떨리잖아.','보고 있으면 쫌 민망한데.')
$hairBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$hairBitmap.BeginInit(); $hairBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$hairBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-hair-heart.png')
$hairBitmap.EndInit(); $hairBitmap.Freeze()
$hairFrames=@(); $hairBounds=@()
for ($i=0;$i -lt 6;$i++) {
 $col=$i%3; $row=[int][Math]::Floor($i/3)
 $x0=[int][Math]::Floor($col*$hairBitmap.PixelWidth/3); $x1=[int][Math]::Floor(($col+1)*$hairBitmap.PixelWidth/3)
 $y0=[int][Math]::Floor($row*$hairBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$hairBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($hairBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Hair-heart atlas crop touches a character edge' }
 $hairFrames+=$frame; $hairBounds+=,$bounds
}
$hairWidth=($hairBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$hairHeight=($hairBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$hairReference=Get-RestBounds $script:sprites[0]
$hairFactor=[Math]::Min(($hairReference[2]-$hairReference[0]+1.0)/$hairWidth,($hairReference[3]-$hairReference[1]+1.0)/$hairHeight)
$script:hairHeartSprites=@()
for ($i=0;$i -lt 6;$i++) {
 $frame=$hairFrames[$i]; $bounds=$hairBounds[$i]
 $x=($hairReference[0]+$hairReference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$hairFactor
 $y=$hairReference[3]-$bounds[3]*$hairFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$hairFactor,$frame.PixelHeight*$hairFactor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:hairHeartSprites+=$image
}
function Get-HairHeartFrame([double]$age) {
 if ($age -lt 0.4) { return 0 }
 if ($age -lt 0.8) { return 1 }
 if ($age -lt 1.2) { return 2 }
 if ($age -lt 1.6) { return 3 }
 if ($age -lt 2.55) { return 4 }
 return 5
}
