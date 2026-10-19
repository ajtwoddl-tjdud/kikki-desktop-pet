# Runtime visual banks. Switching preserves activity clocks, scene state and current frame.
$script:visualStyle='2d'
$script:visualBanks=@{}
$script:visualStylePath=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'Kikki/visual-style.txt'
# The 2D counterparts keep a valid source if a switch occurs on a 3D midpoint.
$script:transitionMidSprites=@()
foreach ($index in @(0,1,2,3,4,5,6,7,8,9,10,4,4)) {
    $copy=$script:transitionSprites[$index].Clone(); $copy.Freeze()
    $script:transitionMidSprites+=$copy
}
$script:visualBindings=@{
 sprites=@('base'); blinkSprites=@('blink'); lookSprites=@('look'); playfulSprites=@('playful')
 dropSprites=@('drop'); restSprites=@('rest'); walkSprites=@('walkPose'); walkCycle=@('walk')
 walkLookCycle=@('glance'); pickupSprites=@('pickup'); liftSprites=@('liftPose'); liftCycle=@('lift')
 backSprites=@('back'); transitionSprites=@('transition'); transitionMidSprites=@('transitionMid'); cameraSprites=@('camera','reels')
 smokeSprites=@('smoke'); hairHeartSprites=@('hairHeart'); noodlesSprites=@('noodles'); extraSprites=@('extra')
}
$smoothSpecs=@{
 walkSmoothSprites=@('walkSmooth','walkCycle',32,4); glanceSmoothSprites=@('glanceSmooth','walkLookCycle',32,4)
 phoneSmoothSprites=@('phoneSmooth','sprites',24,24); heartSmoothSprites=@('heartSmooth','hairHeartSprites',21,4)
 pickupSmoothSprites=@('pickupSmooth','pickupSprites',13,4)
}
foreach ($name in $smoothSpecs.Keys) {
 $spec=$smoothSpecs[$name]; $source=@(Get-Variable -Name $spec[1] -Scope Script -ValueOnly); $frames=@()
 for ($i=0;$i -lt $spec[2];$i++) {
  $index=if ($name -eq 'phoneSmoothSprites') {1} else {[int][Math]::Floor($i/$spec[3])}
  $copy=$source[$index].Clone(); $copy.Freeze(); $frames+=$copy
 }
 Set-Variable -Name $name -Scope Script -Value $frames
 $script:visualBindings[$name]=@($spec[0])
}
$original=@{}
foreach ($name in $script:visualBindings.Keys) { $original[$name]=@(Get-Variable -Name $name -Scope Script -ValueOnly) }
$original['stretchSprite']=$script:stretchSprite
$original['settleSprite']=$script:settleSprite
$script:visualBanks['2d']=$original

function Read-3DVisualBank {
    $root=Join-Path $PSScriptRoot 'assets/rendered-3d'
    $manifest=Get-Content -LiteralPath (Join-Path $root 'manifest.json') -Raw | ConvertFrom-Json
    if ($manifest.version -ne 1 -or $manifest.frameSize -ne 627 -or $manifest.frameCount -ne 257) { throw 'Invalid 3D asset manifest' }
    $bank=@{}; $loaded=@{}
    foreach ($name in $script:visualBindings.Keys) {
        $frames=@()
        foreach ($key in $script:visualBindings[$name]) {
            $property=$manifest.sheets.PSObject.Properties[$key]
            if ($null -eq $property) { throw "Missing 3D sheet: $key" }
            foreach ($path in $property.Value) {
                if ($path -notmatch '^frames/[A-Za-z0-9-]+\.png$') { throw 'Invalid 3D frame path' }
                if (-not $loaded.ContainsKey($path)) {
                    $image=[Windows.Media.Imaging.BitmapImage]::new()
                    $image.BeginInit(); $image.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
                    $image.UriSource=[Uri](Join-Path $root $path); $image.EndInit(); $image.Freeze()
                    if ($image.PixelWidth -ne 627 -or $image.PixelHeight -ne 627) { throw "Invalid 3D frame size: $path" }
                    $loaded[$path]=$image
                }
                $frames+=$loaded[$path]
            }
        }
        if ($frames.Count -ne $script:visualBanks['2d'][$name].Count) { throw "Incomplete 3D animation: $name" }
        $bank[$name]=$frames
    }
    $bank['stretchSprite']=$bank.walkSprites[0].Clone(); $bank['stretchSprite'].Freeze()
    $bank['settleSprite']=$bank.walkSprites[3].Clone(); $bank['settleSprite'].Freeze()
    return $bank
}

function Set-PetVisualStyle([ValidateSet('2d','3d')][string]$Style,[switch]$NoSave) {
    if ($Style -eq $script:visualStyle) { return }
    # Prepare everything first: no partial bank can become visible.
    if (-not $script:visualBanks.ContainsKey($Style)) { $script:visualBanks[$Style]=Read-3DVisualBank }
    $old=$script:visualBanks[$script:visualStyle]; $next=$script:visualBanks[$Style]; $map=@{}
    foreach ($name in $old.Keys) {
        $from=@($old[$name]); $to=@($next[$name])
        for ($i=0;$i -lt $from.Count;$i++) { $map[$from[$i]]=$to[$i] }
    }
    if (-not $NoSave) {
        [void][IO.Directory]::CreateDirectory((Split-Path $script:visualStylePath))
        [IO.File]::WriteAllText($script:visualStylePath,$Style)
    }
    foreach ($name in $next.Keys) { Set-Variable -Name $name -Scope Script -Value $next[$name] }
    foreach ($control in @($script:pet,$script:restBlend,$script:fallingPhone)) {
        if ($null -ne $control.Source -and $map.ContainsKey($control.Source)) { $control.Source=$map[$control.Source] }
    }
    # Cross-fades retain image references; translate them instead of resetting the action.
    foreach ($scene in @($script:rest,$script:poseTransition,$script:cameraScene,$script:cymbalScene,$script:pokeScene,$script:roam)) {
        if ($null -ne $scene) {
            foreach ($key in @($scene.Keys)) {
                $value=$scene[$key]
                if ($null -ne $value -and $value -is [Windows.Media.ImageSource] -and $map.ContainsKey($value)) { $scene[$key]=$map[$value] }
            }
        }
    }
    if ($null -ne $script:pickupPrevious -and $map.ContainsKey($script:pickupPrevious)) { $script:pickupPrevious=$map[$script:pickupPrevious] }
    $script:bubbleHeadCache=@{}
    if ($null -ne $script:poseTransition) {
        $scene=$script:poseTransition; $t=$script:clock.Elapsed.TotalSeconds
        $oldStep=if ($null -ne $scene.step) {[double]$scene.step} else {0.22}
        $phase=($t-$scene.start)/$oldStep
        $scene.step=if ($Style -eq '3d') {0.14} else {0.22}
        $scene.fade=if ($Style -eq '3d') {0.15} else {0.3}
        $scene.start=$t-$phase*$scene.step
        $scene.duration=$scene.route.Count*$scene.step+$scene.fade
    }
    $script:visualStyle=$Style
    if ($null -ne $script:visualStyleItems) {
        foreach ($key in $script:visualStyleItems.Keys) { $script:visualStyleItems[$key].IsChecked=($key -eq $Style) }
    }
}

function Add-VisualStyleMenu {
    $parent=[Windows.Controls.MenuItem]::new();$parent.Header='끼끼 모습 · 2D / 3D'
    $script:visualStyleItems=@{}
    foreach ($key in @('2d','3d')) {
        $item=[Windows.Controls.MenuItem]::new();$item.Tag=$key
        $item.Header=if ($key -eq '2d') {'2D · 원래 끼끼'} else {'3D · 말랑 끼끼'}
        $item.IsCheckable=$false;$item.IsChecked=($script:visualStyle -eq $key)
        $item.Add_Click({
            param($sender,$eventArgs)
            try { Set-PetVisualStyle ([string]$sender.Tag) }
            catch { [void][Windows.MessageBox]::Show("모습을 바꾸지 못했어요. 기존 모습은 유지됩니다.`n$($_.Exception.Message)",'끼끼') }
            $eventArgs.Handled=$true
        })
        $script:visualStyleItems[$key]=$item;[void]$parent.Items.Add($item)
    }
    [void]$script:menu.Items.Insert(0,$parent)
}

if (-not $SelfTest -and (Test-Path -LiteralPath $script:visualStylePath)) {
    try {
        $saved=[IO.File]::ReadAllText($script:visualStylePath).Trim()
        if ($saved -eq '3d') { Set-PetVisualStyle '3d' -NoSave }
    } catch { Write-Warning '3D 이미지를 읽지 못해서 2D로 시작합니다.' }
}
