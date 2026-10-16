$pickupBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$pickupBitmap.BeginInit()
$pickupBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$pickupBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/doongi-pickup.png')
$pickupBitmap.EndInit(); $pickupBitmap.Freeze()
$script:pickupSprites=@()
for ($i=0;$i -lt 4;$i++) {
 $col=$i%2; $row=[int][Math]::Floor($i/2)
 $left=[int][Math]::Floor($col*$pickupBitmap.PixelWidth/2)
 $right=[int][Math]::Floor(($col+1)*$pickupBitmap.PixelWidth/2)
 $top=[int][Math]::Floor($row*$pickupBitmap.PixelHeight/2)
 $bottom=[int][Math]::Floor(($row+1)*$pickupBitmap.PixelHeight/2)
 # Preserve the few pixels of the floor phone extending past the first cell.
 if ($i -eq 0) { $right+=13 }
 if ($i -eq 1) { $left+=13 }
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($pickupBitmap,[Windows.Int32Rect]::new($left,$top,$right-$left,$bottom-$top))
 $script:pickupSprites+=(Align-RestFrame $frame $script:sprites[1])
}
$script:pickupStage=-1
$script:pickupChanged=0.0
function Update-PhonePickup([double]$dropTime) {
 $stage=if ($dropTime -lt 3.75) { 0 } elseif ($dropTime -lt 4.2) { 1 } elseif ($dropTime -lt 4.9) { 2 } else { 3 }
 if ($stage -ne $script:pickupStage) {
  $script:pickupPrevious=if ($script:pickupStage -ge 0) { $script:pickupSprites[$script:pickupStage] } else { $script:pickupSprites[0] }
  $script:pickupStage=$stage
  $script:pickupChanged=$dropTime
 }
 # The phone is drawn in the gripping hand in these frames, never animated alone.
 $script:fallingPhone.Visibility='Hidden'
 $script:pet.Source=$script:pickupSprites[$stage]
 $blend=[Math]::Min(1,($dropTime-$script:pickupChanged)/0.14)
 $script:pet.Opacity=$blend
 $script:restBlend.Source=$script:pickupPrevious
 $script:restBlend.Opacity=1-$blend
 $script:restBlend.Visibility=if ($blend -lt 1) { 'Visible' } else { 'Hidden' }
}
