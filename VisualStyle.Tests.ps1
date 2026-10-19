function Invoke-VisualStyleSelfTest {
    $saved=$script:visualStyle
    Set-PetVisualStyle '2d' -NoSave
    $twoD=$script:sprites[0]
    $script:pet.Source=$twoD
    $modeBefore=$script:mode; $deadline=$script:nextChange
    $script:rest=@{previous=$twoD;lastSource=$twoD;stage=0}
    $previousCamera=$script:cameraScene
    $script:cameraScene=@{previous=$twoD;previousFrameSource=$twoD;lastFrameSource=$twoD}
    Set-PetVisualStyle '3d' -NoSave
    if ([object]::ReferenceEquals($twoD,$script:sprites[0])) { throw '3D did not switch images' }
    if (-not [object]::ReferenceEquals($script:pet.Source,$script:sprites[0])) { throw 'Active source was not switched' }
    if (-not [object]::ReferenceEquals($script:rest.previous,$script:sprites[0])) { throw 'Crossfade retained a 2D source' }
    if (-not [object]::ReferenceEquals($script:cameraScene.previousFrameSource,$script:sprites[0])) { throw 'Camera crossfade retained a 2D source' }
    if ($script:mode -ne $modeBefore -or $script:nextChange -ne $deadline) { throw 'Style change reset activity state' }
    foreach ($name in $script:visualBindings.Keys) {
        $frames=@(Get-Variable -Name $name -Scope Script -ValueOnly)
        if ($frames.Count -ne $script:visualBanks['2d'][$name].Count) { throw "Frame count mismatch: $name" }
        foreach ($frame in $frames) {
            $bounds=Get-RestBounds $frame
            if ($bounds[0] -le 0 -or $bounds[1] -le 0 -or $bounds[2] -ge 626 -or $bounds[3] -ge 626) { throw "Empty/clipped 3D sprite: $name" }
        }
    }
    $script:motion=$true; $script:pressed=$false; $script:dragging=$false
    $t=$script:clock.Elapsed.TotalSeconds
    Start-PostureTransition 0 2 $t $script:sprites[0]
    if ($script:poseTransition.step -ne 0.14) { throw '3D posture transition did not accelerate' }
    Render-PostureTransition ($t+0.08)
    if (-not [object]::ReferenceEquals($script:pet.Source,$script:transitionMidSprites[0])) { throw '3D posture transition did not use its middle pose' }
    $script:poseTransition=$null
    $script:pet.Source=$script:sprites[0]
    Set-PetVisualStyle '2d' -NoSave
    if (-not [object]::ReferenceEquals($script:pet.Source,$twoD)) { throw 'Switching back did not restore original source' }
    $script:rest=$null
    $script:cameraScene=$previousCamera
    Set-PetVisualStyle $saved -NoSave
    Write-Output 'PASS: 2D/3D banks, all 257 frames, active/crossfade source remapping and unchanged activity deadline.'
}
