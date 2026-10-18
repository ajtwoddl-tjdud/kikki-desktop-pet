# Independent minute-scale clocks keep activity changes from postponing walks and details.
$script:quietUntil=0.0
$script:previousActivity=-1
$script:lifeActionBag=@()
$script:lastLifeAction=''
function Get-NextLifeAction {
 if ($script:lifeActionBag.Count -eq 0) {
  $remaining=@('selfie','reels','smoke','hairHeart','noodles')
  $bag=@()
  while ($remaining.Count -gt 0) {
   $choices=@($remaining | Where-Object { $bag.Count -gt 0 -or $_ -ne $script:lastLifeAction })
   $pick=$choices[$script:rng.Next($choices.Count)]
   $bag+=$pick; $remaining=@($remaining | Where-Object { $_ -ne $pick })
  }
  $script:lifeActionBag=$bag
 }
 $script:lastLifeAction=$script:lifeActionBag[0]
 $script:lifeActionBag=@($script:lifeActionBag | Select-Object -Skip 1)
 return $script:lastLifeAction
}
. (Join-Path $PSScriptRoot 'Routes.ps1')
function Get-ActivitySeconds([int]$mode) {
 return $script:rng.Next(120,241)
}
function Get-RestHoldSeconds([int]$mode) {
 if ($mode -in @(1,2)) { return $script:rng.Next(120,211) }
 return 4.0
}
function Get-FirstRestDelay([int]$mode) {
 if ($mode -in @(1,2)) { return $script:rng.Next(25,56) }
 return $script:rng.Next(120,241)
}
function Get-NextActivityMode([int]$mode,[int]$previous,[int]$roll) {
 if ($mode -eq 2) { return 1 }
 $choices=@(0..3 | Where-Object { $_ -ne $mode -and $_ -ne $previous })
 return $choices[$roll % $choices.Count]
}
function Get-WalkDestination([double]$from,[double]$low,[double]$high,[bool]$across,[double]$offset) {
 $high=[Math]::Max($low,$high)
 if ($across) {
  if ($from -ge ($low+$high)/2) { return $low }
  return $high
 }
 $target=[Math]::Max($low,[Math]::Min($high,$from+$offset))
 if ([Math]::Abs($target-$from) -lt 180) { $target=[Math]::Max($low,[Math]::Min($high,$from-$offset)) }
 return $target
}
function Test-RoamDue([double]$t) {
 return -not $script:chaosEnabled -and $null -eq $script:cameraScene -and $script:roamEnabled -and $script:motion -and $script:mode -ne 2 -and $t -ge $script:nextRoam
}
function Get-DueDetail([double]$t) {
 if ($script:chaosEnabled -or $null -ne $script:cameraScene) { return '' }
 if (-not $script:motion -or $t -lt $script:quietUntil -or $script:pressed -or $script:dragging -or $t -lt $script:attentionEnd -or $t -lt $script:sulkEnd -or $t -lt $script:expressionEnd -or $null -ne $script:poseTransition -or $null -ne $script:roam -or $null -ne $script:rest -or $null -ne $script:dropStart -or $null -ne $script:backTurn) { return '' }
 # Once a long rest finishes, give the overdue short activity its turn before another rest/walk.
 if ($script:auto -and $script:mode -ne 2 -and $null -ne $script:nextCamera -and $script:nextCamera -le $t) { return 'camera' }
 if (Test-RoamDue $t) { return '' }
 $action=''; $deadline=[double]::PositiveInfinity
 if ($script:nextRest -le $t) { $action='rest'; $deadline=$script:nextRest }
 if ($script:mode -eq 1 -and $script:nextDrop -le $t -and $script:nextDrop -lt $deadline) { $action='drop'; $deadline=$script:nextDrop }
 if ($script:mode -ne 2 -and $script:nextExpression -le $t -and $script:nextExpression -lt $deadline) { $action='expression'; $deadline=$script:nextExpression }
 if ($script:auto -and $script:mode -ne 2 -and $script:nextBack -le $t -and $script:nextBack -lt $deadline) { $action='back'; $deadline=$script:nextBack }
 return $action
}
function Continue-Life {
 $finishedGame=($script:mode -eq 3)
 $next=Get-NextActivityMode $script:mode $script:previousActivity ($script:rng.Next(100))
 Set-Pose $next
 if ($finishedGame) { Say-Random 'gameLoss' } else { Say-Random }
}
