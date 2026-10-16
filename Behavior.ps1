# Activities last minutes; small movements never count as a new activity.
$script:quietUntil=0.0
function Get-ActivitySeconds([int]$mode) {
 switch ($mode) {
  0 { return $script:rng.Next(75,151) }
  1 { return $script:rng.Next(360,841) }
  2 { return $script:rng.Next(720,1501) }
  3 { return $script:rng.Next(300,721) }
 }
}
function Continue-Life {
 # Often stay with the same pastime; never cycle through the pose list.
 $roll=$script:rng.Next(100)
 $next=switch ($script:mode) {
  0 { if ($roll -lt 70) { 1 } else { 3 } }
  1 { if ($roll -lt 45) { 1 } elseif ($roll -lt 80) { 2 } else { 3 } }
  2 { if ($roll -lt 35) { 2 } else { 1 } }
  3 { if ($roll -lt 40) { 3 } elseif ($roll -lt 85) { 1 } else { 0 } }
 }
 if ($next -eq $script:mode) {
  $script:nextChange=[DateTime]::Now.AddSeconds((Get-ActivitySeconds $next))
 } else { Set-Pose $next }
}
