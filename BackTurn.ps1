$script:backTurn=$null
$script:nextBack=420.0
$backBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$backBitmap.BeginInit()
$backBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$backBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-back.png')
$backBitmap.EndInit(); $backBitmap.Freeze()
$script:backSprites=@()
for ($i=0;$i -lt 4;$i++) {
 $col=$i%2; $row=[int][Math]::Floor($i/2)
 $x0=[int][Math]::Floor($col*$backBitmap.PixelWidth/2); $x1=[int][Math]::Floor(($col+1)*$backBitmap.PixelWidth/2)
 $y0=[int][Math]::Floor($row*$backBitmap.PixelHeight/2); $y1=[int][Math]::Floor(($row+1)*$backBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($backBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $script:backSprites+=(Align-RestFrame $frame $script:sprites[0])
}
function Stop-BackTurn([double]$t) {
 if ($null -eq $script:backTurn) { return }
 $script:backTurn=$null
 $script:nextBack=$t+$script:rng.Next(420,901)
}
function Start-BackTurn([double]$t) {
 if ($null -ne $script:poseTransition) { return }
 if ($script:pressed -or $script:dragging -or $t -lt $script:sulkEnd -or $t -lt $script:attentionEnd) { return }
 Stop-Rest $t; Stop-Roam $t 45
 $script:dropStart=$null; $script:expressionEnd=0
 $script:backTurn=@{until=$t+$script:rng.Next(35,76);peek=-10.0}
 $script:fallingPhone.Visibility='Hidden'
$script:quietUntil=$t+150
}
function Update-BackTurn([double]$t) {
 if ($null -eq $script:backTurn) {
  if ($script:mode -ne 2 -and $t -ge $script:quietUntil -and -not $SelfTest -and $script:auto -and $script:motion -and $t -ge $script:nextBack -and $null -eq $script:rest -and $null -eq $script:roam -and $null -eq $script:dropStart -and -not $script:pet.ContextMenu.IsOpen) { Start-BackTurn $t }
  if ($null -eq $script:backTurn) { return }
 }
 if ($script:dragging -or $t -ge $script:backTurn.until) { Stop-BackTurn $t; return }
 $age=$t-$script:backTurn.peek
 $frame=0
 if ($age -ge 0 -and $age -lt 2.6) {
  if ($script:motion -and ($age -lt 0.14 -or $age -gt 2.42)) { $frame=1 }
  elseif ($script:motion -and $age -gt 1.2 -and $age -lt 1.34) { $frame=3 }
  else { $frame=2 }
 }
 $script:pet.Source=$script:backSprites[$frame]; $script:pet.Opacity=1
 $script:restBlend.Visibility='Hidden'; $script:fallingPhone.Visibility='Hidden'; $script:sleepMark.Visibility='Hidden'
 $tr=$script:pet.RenderTransform.Children
 $tr[0].ScaleX=1; $tr[0].ScaleY=1
 if ($script:motion) { $tr[0].ScaleY=1+0.002*[Math]::Sin($t*1.1) }
 $tr[1].Angle=0; $tr[2].X=0; $tr[2].Y=0; $tr[3].AngleX=0
 [Windows.Controls.Canvas]::SetTop($script:groundShadow,241)
 $script:groundShadow.Opacity=0.7
}
