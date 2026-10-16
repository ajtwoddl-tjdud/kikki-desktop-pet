# Small local walks: stretch, toddle a few steps, settle back into the activity.
$script:roamEnabled=$true
$script:roam=$null
$script:nextRoam=$script:rng.Next(120,241)
$script:homeX=$null
$script:walkSprites=@()
$walkBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$walkBitmap.BeginInit()
$walkBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$walkBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-walk.png')
$walkBitmap.EndInit()
$walkBitmap.Freeze()
$walkWidth=[int]($walkBitmap.PixelWidth/2); $walkHeight=[int]($walkBitmap.PixelHeight/2)
for ($i=0; $i -lt 4; $i++) {
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($walkBitmap,[Windows.Int32Rect]::new(($i%2)*$walkWidth,[int][Math]::Floor($i/2)*$walkHeight,$walkWidth,$walkHeight))
    $frame.Freeze()
    $script:walkSprites+=$frame
}
Add-Type @'
public static class DoongiFrameBounds {
    public static double[] Measure(byte[] pixels, int width, int height, int stride) {
        int minY=height,maxY=0;
        for(int y=0;y<height;y++) for(int x=0;x<width;x++) {
            if(pixels[y*stride+x*4+3]>32) { if(y<minY)minY=y; if(y>maxY)maxY=y; }
        }
        int row=minY+(int)((maxY-minY)*0.34), left=width, right=0;
        for(int x=0;x<width;x++) if(pixels[row*stride+x*4+3]>32) { if(x<left)left=x; if(x>right)right=x; }
        return new double[] { minY, maxY, (left+right)/2.0 };
    }
}
'@
function Align-WalkFrame($source, [double]$bodyHeight=470) {
    $converted=[Windows.Media.Imaging.FormatConvertedBitmap]::new($source,[Windows.Media.PixelFormats]::Bgra32,$null,0)
    $stride=$converted.PixelWidth*4
    $pixels=New-Object byte[] ($stride*$converted.PixelHeight)
    $converted.CopyPixels($pixels,$stride,0)
    $bounds=[DoongiFrameBounds]::Measure($pixels,$converted.PixelWidth,$converted.PixelHeight,$stride)
    $factor=$bodyHeight/($bounds[1]-$bounds[0]+1)
    $group=[Windows.Media.DrawingGroup]::new()
    $ctx=$group.Open()
    $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
    $ctx.DrawImage($source,[Windows.Rect]::new(290-$bounds[2]*$factor,590-$bounds[1]*$factor,$source.PixelWidth*$factor,$source.PixelHeight*$factor))
    $ctx.Close()
    $group.ClipGeometry=[Windows.Media.RectangleGeometry]::new([Windows.Rect]::new(0,0,627,627))
    $image=[Windows.Media.DrawingImage]::new($group)
    $image.Freeze()
    return $image
}
$script:stretchSprite=Align-WalkFrame $script:walkSprites[0] 510
$script:settleSprite=Align-WalkFrame $script:walkSprites[3] 425
$cycleBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$cycleBitmap.BeginInit()
$cycleBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$cycleBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-walk-cycle.png')
$cycleBitmap.EndInit()
$cycleBitmap.Freeze()
$script:walkCycle=@()
for ($i=0; $i -lt 8; $i++) {
    $column=$i%4; $row=[int][Math]::Floor($i/4)
    $x0=[int][Math]::Floor($column*$cycleBitmap.PixelWidth/4)
    $x1=[int][Math]::Floor(($column+1)*$cycleBitmap.PixelWidth/4)
    $y0=[int][Math]::Floor($row*$cycleBitmap.PixelHeight/2)
    $y1=[int][Math]::Floor(($row+1)*$cycleBitmap.PixelHeight/2)
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($cycleBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
    $script:walkCycle+= (Align-WalkFrame $frame)
}
$walkLookBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$walkLookBitmap.BeginInit()
$walkLookBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$walkLookBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-walk-glance.png')
$walkLookBitmap.EndInit(); $walkLookBitmap.Freeze()
$script:walkLookCycle=@()
for ($i=0;$i -lt 8;$i++) {
    $col=$i%4; $row=[int][Math]::Floor($i/4)
    $x0=[int][Math]::Floor($col*$walkLookBitmap.PixelWidth/4); $x1=[int][Math]::Floor(($col+1)*$walkLookBitmap.PixelWidth/4)
    $y0=[int][Math]::Floor($row*$walkLookBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$walkLookBitmap.PixelHeight/2)
    $frame=[Windows.Media.Imaging.CroppedBitmap]::new($walkLookBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
    $script:walkLookCycle+=(Align-WalkFrame $frame)
}
function Get-WalkDistance([double]$time, [double]$total, [double]$duration) {
    $ramp=0.45
    $speed=$total/($duration-$ramp)
    if ($time -le 0) { return 0.0 }
    if ($time -ge $duration) { return $total }
    if ($time -lt $ramp) { return $speed*($time/2-$ramp*[Math]::Sin([Math]::PI*$time/$ramp)/(2*[Math]::PI)) }
    if ($time -gt $duration-$ramp) {
        $left=$duration-$time
        return $total-$speed*($left/2-$ramp*[Math]::Sin([Math]::PI*$left/$ramp)/(2*[Math]::PI))
    }
    return $speed*($time-$ramp/2)
}
function Stop-Roam([double]$t, [int]$restSeconds=0) {
    if ($restSeconds -eq 0) { $restSeconds=$script:rng.Next(120,241) }
    $script:roam=$null
    $script:nextRoam=$t+$restSeconds
}
function Start-Roam([double]$t, [switch]$Across) {
    if ($null -ne $script:poseTransition) { return }
    if ($null -ne $script:backTurn) { return }
    if ($t -lt $script:expressionEnd -or -not $script:roamEnabled -or -not $script:motion -or $script:dragging -or $script:pressed -or $null -ne $script:roam -or $null -ne $script:dropStart -or $null -ne $script:rest -or $t -lt $script:attentionEnd) { return }
    $area=[Windows.SystemParameters]::WorkArea
    if ($null -eq $script:homeX) { $script:homeX=$script:window.Left }
    $low=$area.Left+12
    $high=[Math]::Max($low,$area.Right-$script:window.Width-12)
    $offset=(1-2*$script:rng.Next(2))*$script:rng.Next(260,561)
    $crossing=[bool]$Across
    $destination=Get-WalkDestination $script:window.Left $low $high $crossing $offset
    if ([Math]::Abs($destination-$script:window.Left) -lt 12) { $script:nextRoam=$t+$script:rng.Next(120,241); return }
    $script:roam=@{
        start=$t; fromX=$script:window.Left; toX=$destination
        seconds=[Math]::Abs($destination-$script:window.Left)/104+0.45
        direction=[Math]::Sign($destination-$script:window.Left)
        crossing=$crossing; pausedAt=$null; pauseUntil=0.0
        frameIndex=0; strideY=0.0; strideAngle=0.0
    }
    $script:expressionEnd=0
    $script:quietUntil=[Math]::Max($script:quietUntil,$t+$script:roam.seconds+4.9)
    if ($script:rng.Next(3) -eq 0) { Say-Random 'walk' }
}
function Update-Roam([double]$t) {
    if ($null -eq $script:roam) {
        if ((Test-RoamDue $t) -and -not $SelfTest -and -not $script:pet.ContextMenu.IsOpen) { Start-Roam $t -Across }
        if ($null -eq $script:roam) { return }
    }
    if (-not $script:motion -or -not $script:roamEnabled -or $script:dragging) { Stop-Roam $t; return }
    if ($script:pressed -and $null -eq $script:roam.pausedAt) { $script:roam.pausedAt=$t }
    if ($null -ne $script:roam.pausedAt) {
        if ($script:pressed -or $t -lt $script:roam.pauseUntil) {
            $step=$script:roam.frameIndex
            $script:pet.Source=$script:walkLookCycle[$step]
            $tr=$script:pet.RenderTransform.Children
            $tr[0].ScaleX=-$script:roam.direction; $tr[0].ScaleY=1
            $tr[1].Angle=$script:roam.strideAngle; $tr[2].X=0; $tr[2].Y=$script:roam.strideY; $tr[3].AngleX=0
            $script:restBlend.Visibility='Hidden'; $script:fallingPhone.Visibility='Hidden'; $script:sleepMark.Visibility='Hidden'
            [Windows.Controls.Canvas]::SetTop($script:groundShadow,252)
            $script:groundShadow.RenderTransform.ScaleX=0.75; $script:groundShadow.Opacity=0.7
            $turn=[Math]::Min(1.0,($t-$script:roam.pausedAt)/0.1)
            if ($turn -lt 1 -and $script:motion) {
                $script:restBlend.Source=$script:walkCycle[$step]
                $script:restBlend.Opacity=1-$turn; $script:restBlend.Visibility='Visible'
                $script:pet.Opacity=$turn
            }
            return
        }
        # Resume from the same stride and position after looking at the owner.
        $resumeAt=$t
        if ($script:roam.pauseUntil -gt $script:roam.pausedAt) { $resumeAt=$script:roam.pauseUntil }
        $script:roam.start+=$resumeAt-$script:roam.pausedAt
        $script:roam.pausedAt=$null
        $script:roam.pauseUntil=0.0
        $script:attentionEnd=0
        if ($script:words.Text -eq '왜? 뭐? 산책하는 끼끼 처음 봐?') { $script:bubble.Visibility='Hidden' }
    }
    $elapsed=$t-$script:roam.start
    $walkTime=$elapsed-1.1
    $transforms=$script:pet.RenderTransform.Children
    $transforms[0].ScaleX=1; $transforms[0].ScaleY=1
    $transforms[1].Angle=0
    $transforms[2].X=0; $transforms[2].Y=0
    $transforms[3].AngleX=0
    $script:sleepMark.Visibility='Hidden'
    $script:fallingPhone.Visibility='Hidden'
    [Windows.Controls.Canvas]::SetTop($script:groundShadow,252)
    $script:groundShadow.RenderTransform.ScaleX=0.75
    $script:groundShadow.Opacity=0.7
    if ($elapsed -lt 1.1) {
        $script:pet.Source=$script:stretchSprite
        $transforms[0].ScaleY=1+0.025*[Math]::Sin($elapsed/1.1*[Math]::PI)
    } elseif ($walkTime -lt $script:roam.seconds) {
        $total=[Math]::Abs($script:roam.toX-$script:roam.fromX)
        $travel=Get-WalkDistance $walkTime $total $script:roam.seconds
        $script:window.Left=$script:roam.fromX+$script:roam.direction*$travel
        # Distance drives the gait, including the gentle start and stop.
        $phase=($travel/56)%1
        $frameIndex=[int][Math]::Floor($phase*8)
        $script:roam.frameIndex=$frameIndex
        $script:pet.Source=$script:walkCycle[$frameIndex]
        $transforms[0].ScaleX=-$script:roam.direction
        $transforms[2].Y=-0.6*(1-[Math]::Cos($phase*[Math]::PI*4))/2
        $transforms[1].Angle=0.4*[Math]::Sin($phase*[Math]::PI*2)
        $script:roam.strideY=$transforms[2].Y
        $script:roam.strideAngle=$transforms[1].Angle
    } elseif ($walkTime -lt $script:roam.seconds+0.8) {
        $script:window.Left=$script:roam.toX
        $script:pet.Source=$script:settleSprite
        $settle=($walkTime-$script:roam.seconds)/0.8
        $transforms[0].ScaleY=1-0.018*[Math]::Sin($settle*[Math]::PI)
    } else {
        $script:window.Left=$script:roam.toX
        Stop-Roam $t ($script:rng.Next(120,241))

    }
}
