function Get-RoutePosition($route,[double]$distance) {
 $distance=[Math]::Max(0.0,[Math]::Min([double]$route.length,$distance))
 $points=$route.points
 for ($i=1;$i -lt $points.Count;$i++) {
  if ($points[$i].distance -lt $distance -and $i -lt $points.Count-1) { continue }
  $a=$points[$i-1]; $b=$points[$i]
  $length=$b.distance-$a.distance
  $u=if ($length -gt 0.0001) {($distance-$a.distance)/$length} else {1.0}
  return @{x=$a.x+($b.x-$a.x)*$u;y=$a.y+($b.y-$a.y)*$u;direction=[Math]::Sign($b.x-$a.x)}
 }
 return @{x=$points[0].x;y=$points[0].y;direction=0}
}
function New-ChaosRoute([double]$fromX,[double]$fromY,[double]$left,[double]$top,[double]$right,[double]$bottom,[double]$petWidth,[int]$shape=-1) {
 $right=[Math]::Max($left,$right); $bottom=[Math]::Max($top,$bottom)
 $w=$right-$left; $h=$bottom-$top
 $x=[Math]::Max($left,[Math]::Min($right,$fromX)); $y=[Math]::Max($top,[Math]::Min($bottom,$fromY))
 $endX=if ($x -ge ($left+$right)/2) {$left} else {$right}
 $nearX=if ($endX -eq $left) {$right} else {$left}
 $upper=$top+$h*(0.08+0.12*$script:rng.NextDouble())
 $lower=$top+$h*(0.80+0.12*$script:rng.NextDouble())
 $endY=$top+$h*(0.15+0.7*$script:rng.NextDouble())
 if ($shape -lt 0) { $shape=$script:rng.Next(3) }
 $raw=@(@{x=$x;y=$y})
 switch ($shape) {
  0 {
   $raw+=@{x=$x+($endX-$x)*0.3;y=$upper}
   $raw+=@{x=$x+($endX-$x)*0.68;y=$lower}
  }
  1 {
   # Briefly leave by a side edge, then bend back into the visible work area.
   $outside=if ($endX -eq $left) {$left-$petWidth-80} else {$right+$petWidth+80}
   $raw+=@{x=$outside;y=$upper}
   $raw+=@{x=$nearX+($endX-$nearX)*0.30;y=$lower}
  }
  2 {
   $raw+=@{x=$nearX+($endX-$nearX)*0.85;y=$upper}
   $raw+=@{x=$nearX+($endX-$nearX)*0.20;y=$lower}
  }
 }
 $raw+=@{x=$endX;y=$endY}
 $samples=New-Object 'System.Collections.Generic.List[object]'
 $samples.Add($raw[0])
 for ($i=1;$i -lt $raw.Count-1;$i++) {
  $a=$raw[$i-1]; $b=$raw[$i]; $c=$raw[$i+1]
  $incoming=[Math]::Sqrt([Math]::Pow($b.x-$a.x,2)+[Math]::Pow($b.y-$a.y,2))
  $outgoing=[Math]::Sqrt([Math]::Pow($c.x-$b.x,2)+[Math]::Pow($c.y-$b.y,2))
  $radius=[Math]::Min(65.0,[Math]::Min($incoming,$outgoing)*0.18)
  if ($radius -lt 0.001) { $samples.Add($b); continue }
  $entry=@{x=$b.x-($b.x-$a.x)/$incoming*$radius;y=$b.y-($b.y-$a.y)/$incoming*$radius}
  $exit=@{x=$b.x+($c.x-$b.x)/$outgoing*$radius;y=$b.y+($c.y-$b.y)/$outgoing*$radius}
  $samples.Add($entry)
  for ($j=1;$j -le 8;$j++) {
   $u=$j/8.0; $v=1-$u
   $samples.Add(@{x=$v*$v*$entry.x+2*$v*$u*$b.x+$u*$u*$exit.x;y=$v*$v*$entry.y+2*$v*$u*$b.y+$u*$u*$exit.y})
  }
 }
 $samples.Add($raw[$raw.Count-1])
 $points=New-Object 'System.Collections.Generic.List[object]'
 $distance=0.0; $previous=$null
 foreach ($point in $samples) {
  if ($null -ne $previous) { $distance+=[Math]::Sqrt([Math]::Pow($point.x-$previous.x,2)+[Math]::Pow($point.y-$previous.y,2)) }
  $points.Add(@{x=[double]$point.x;y=[double]$point.y;distance=$distance})
  $previous=$point
 }
 return @{points=$points.ToArray();length=$distance;endX=$endX;endY=$endY;shape=$shape}
}
