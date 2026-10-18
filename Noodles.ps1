$noodleBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$noodleBitmap.BeginInit(); $noodleBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$noodleBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-spicy-noodles.png')
$noodleBitmap.EndInit(); $noodleBitmap.Freeze()
$script:extraLines.noodles=@('한 입만 먹고.','이거 쫌 먹어볼게.','맛있겠다.','물도 갖다 놨어.')
$script:extraLines.noodlesEatPoke=@('왜. 한 입 줄까?','잠깐. 면 끊겨.','먹고 얘기해.','너도 먹을래?')
$script:extraLines.noodlesHotPoke=@('아 안 매운 줄.','잠깐. 말 시키지 마.','안 매워. …물 어딨어.','웃지 마. 너도 먹어봐.')
$script:extraLines.noodlesWaterPoke=@('물부터 마시고.','잠깐. 아직 매워.','너도 물 갖다 놓고 먹어.','다음엔 소스 쫌만 넣을래.')
$noodleFrames=@(); $noodleBounds=@()
for ($i=0;$i -lt 6;$i++) {
 $col=$i%3; $row=[int][Math]::Floor($i/3)
 $x0=[int][Math]::Floor($col*$noodleBitmap.PixelWidth/3); $x1=[int][Math]::Floor(($col+1)*$noodleBitmap.PixelWidth/3)
 $y0=[int][Math]::Floor($row*$noodleBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$noodleBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($noodleBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $bounds=Get-RestBounds $frame
 if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge $frame.PixelWidth-1 -or $bounds[3] -ge $frame.PixelHeight-1) { throw 'Spicy-noodle atlas crop touches a character edge' }
 $noodleFrames+=$frame; $noodleBounds+=,$bounds
}
$noodleWidth=($noodleBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$noodleHeight=($noodleBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$noodleReference=Get-RestBounds $script:sprites[0]
$noodleFactor=[Math]::Min(($noodleReference[2]-$noodleReference[0]+1.0)/$noodleWidth,($noodleReference[3]-$noodleReference[1]+1.0)/$noodleHeight)
$script:noodlesSprites=@()
for ($i=0;$i -lt 6;$i++) {
 $frame=$noodleFrames[$i]; $bounds=$noodleBounds[$i]
 $x=($noodleReference[0]+$noodleReference[2])/2.0-($bounds[0]+$bounds[2])/2.0*$noodleFactor
 $y=$noodleReference[3]-$bounds[3]*$noodleFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$noodleFactor,$frame.PixelHeight*$noodleFactor)); $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:noodlesSprites+=$image
}
function Get-NoodlesFrame([double]$age) {
 if ($age -lt 0.35) { return 0 }
 if ($age -lt 0.95) { return 1 }
 if ($age -lt 1.35) { return 2 }
 if ($age -lt 2.15) { return 3 }
 if ($age -lt 2.5) { return 4 }
 return 5
}
function Get-NoodlesPokeContext([double]$t) {
 $age=($t-$script:cameraScene.start)*3.0/$script:cameraScene.duration
 $frame=Get-NoodlesFrame $age
 if ($frame -lt 2) { return 'noodlesEatPoke' }
 if ($frame -lt 4) { return 'noodlesHotPoke' }
 return 'noodlesWaterPoke'
}
