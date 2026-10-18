Add-Type -TypeDefinition ([IO.File]::ReadAllText((Join-Path $PSScriptRoot 'Runtime.cs')))
$script:visibilityWatcher=$null
$script:scheduledClassEnd=$null

function Complete-ClassTimer {
    if ($null -eq $script:classEnd -or [DateTime]::Now -lt $script:classEnd) { return }
    $script:classEnd=$null
    if ($script:window.IsVisible) { Say-Random 'classEnd'; $script:bubbleUntil=[DateTime]::Now.AddSeconds(12) }
    else { $script:pendingClassEnd=$true }
}

function Sync-PetTimers {
    $active=$null -ne $script:cymbalScene -or $script:chaosEnabled -or $null -ne $script:cameraScene -or $null -ne $script:pokeScene -or $script:pressed -or $script:dragging -or $null -ne $script:roam -or $null -ne $script:poseTransition -or $null -ne $script:dropStart -or $script:clock.Elapsed.TotalSeconds -lt $script:sulkEnd
    $milliseconds=[KikkiUpdateSchedule]::FrameMilliseconds($script:window.IsVisible,$script:motion,$active)
    if ($milliseconds -eq 0) { $script:timer.Stop() }
    else {
        $interval=[TimeSpan]::FromMilliseconds($milliseconds)
        if ($script:timer.Interval -ne $interval) { $script:timer.Interval=$interval }
        if (-not $script:timer.IsEnabled) { $script:timer.Start() }
    }
    if ($script:scheduledClassEnd -ne $script:classEnd) {
        $script:classTimer.Stop()
        $script:scheduledClassEnd=$script:classEnd
        if ($null -ne $script:classEnd) {
            $script:classTimer.Interval=[TimeSpan]::FromMilliseconds([Math]::Max(1,($script:classEnd-[DateTime]::Now).TotalMilliseconds))
            $script:classTimer.Start()
        }
    }
}
