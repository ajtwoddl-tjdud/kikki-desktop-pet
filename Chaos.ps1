# Camera scenes are also usable alone; chaos mode only changes their scheduling.
$script:chaosEnabled=$false
$script:chaosNext=0.0
$script:chaosSaved=$null
$script:chaosLast=''
$script:cameraScene=$null
$script:nextCamera=$script:rng.Next(120,241)
$script:pokeScene=$null
$script:lastPokeAt=-10.0
$script:pokeCount=0
$script:extraLines.selfie=@('잠깐. 사진 한 장만.', '이쪽으로 찍어볼까.', '아 눈 감았어. 다시.', '한 장만 더.', '잠깐. 각도 쫌.', '잘 나왔나 볼래.')
$script:extraLines.reels=@('한 번만 찍어볼게.', '이거 올릴까 말까.', '잠깐. 박자 쫌 세고.', '이번엔 안 틀릴게.', '아 다시. 박자 놓쳤어.', '찍고 확인해보자.')
$script:extraLines.selfiePoke=@('잠깐. 나 지금 눈 감았어. 다시.', '구경만 하지 말고 찍어줘.', '아 사진에 손 나와.', '이쪽 말고 반대쪽에서.', '잠깐. 아직 안 찍었어.', '잘 나왔나 봐줘.')
$script:extraLines.reelsPoke=@('아 언제부터 봤어.', '아 쫌. 찍고 있잖아.', '웃지 마. 박자 세는 중이야.', '방금 건 다시 찍을 거야.', '잠깐. 여기부터 다시.', '볼 거면 박수라도 쳐줘.')
$script:extraLines.repeatPoke=@('알았어. 보고 있잖아.', '아 쫌. 간지러.', '왜 자꾸 불러.', '할 말 생각하고 눌러.', '응. 아직 여기 있어.', '잠깐. 하나씩 말해.', '나 좀 그만 좋아해.', '그만 쳐다봐.', '알았어. 나도 너 봤어.')

$cameraBitmap=[Windows.Media.Imaging.BitmapImage]::new()
$cameraBitmap.BeginInit()
$cameraBitmap.CacheOption=[Windows.Media.Imaging.BitmapCacheOption]::OnLoad
$cameraBitmap.UriSource=[Uri](Join-Path $PSScriptRoot 'assets/kikki-camera.png')
$cameraBitmap.EndInit(); $cameraBitmap.Freeze()
$cameraFrames=@(); $cameraBounds=@()
for ($i=0;$i -lt 8;$i++) {
 $x0=[int][Math]::Floor(($i%4)*$cameraBitmap.PixelWidth/4)
 $x1=[int][Math]::Floor((($i%4)+1)*$cameraBitmap.PixelWidth/4)
 $row=[int][Math]::Floor($i/4)
 $y0=[int][Math]::Floor($row*$cameraBitmap.PixelHeight/2)
 $y1=[int][Math]::Floor(($row+1)*$cameraBitmap.PixelHeight/2)
 $frame=[Windows.Media.Imaging.CroppedBitmap]::new($cameraBitmap,[Windows.Int32Rect]::new($x0,$y0,$x1-$x0,$y1-$y0))
 $cameraFrames+=$frame; $cameraBounds+=,(Get-RestBounds $frame)
}
$cameraWidth=($cameraBounds | ForEach-Object { $_[2]-$_[0]+1 } | Measure-Object -Maximum).Maximum
$cameraHeight=($cameraBounds | ForEach-Object { $_[3]-$_[1]+1 } | Measure-Object -Maximum).Maximum
$cameraRef=Get-RestBounds $script:sprites[0]
$cameraFactor=[Math]::Min(($cameraRef[2]-$cameraRef[0]+1.0)/$cameraWidth,($cameraRef[3]-$cameraRef[1]+1.0)/$cameraHeight)
$script:cameraSprites=@()
for ($i=0;$i -lt 8;$i++) {
 $frame=$cameraFrames[$i]; $bounds=$cameraBounds[$i]
 $x=($cameraRef[0]+$cameraRef[2])/2.0-($bounds[0]+$bounds[2])/2.0*$cameraFactor
 $y=$cameraRef[3]-$bounds[3]*$cameraFactor
 $group=[Windows.Media.DrawingGroup]::new(); $ctx=$group.Open()
 $ctx.DrawRectangle([Windows.Media.Brushes]::Transparent,$null,[Windows.Rect]::new(0,0,627,627))
 $ctx.DrawImage($frame,[Windows.Rect]::new($x,$y,$frame.PixelWidth*$cameraFactor,$frame.PixelHeight*$cameraFactor))
 $ctx.Close()
 $image=[Windows.Media.DrawingImage]::new($group); $image.Freeze(); $script:cameraSprites+=$image
}
. (Join-Path $PSScriptRoot 'Reels.ps1')
. (Join-Path $PSScriptRoot 'Smoking.ps1')
. (Join-Path $PSScriptRoot 'HairHeart.ps1')
. (Join-Path $PSScriptRoot 'Noodles.ps1')
function Start-CameraScene([string]$kind,[double]$t,[ValidateRange(-1,3)][int]$ReelsStyle=-1) {
 if ($script:pressed -or $script:dragging) { return }
 $returnMode=$script:mode; $previous=$script:pet.Source
 Set-Pose 0 -Immediate
 $style=0
 if ($kind -eq 'reels') {
  if ($ReelsStyle -lt 0) { $style=Get-NextReelsStyle }
  else { $style=$ReelsStyle; $script:previousReelsStyle=$style }
 }
 $duration=if (-not $script:chaosEnabled -and $kind -eq 'noodles') {10.0} elseif (-not $script:chaosEnabled -and $kind -eq 'smoke') {6.5} elseif (-not $script:chaosEnabled -and $kind -eq 'hairHeart') {5.6} else {3.0}
 $script:cameraScene=@{kind=$kind;start=$t;returnMode=$returnMode;previous=$previous;style=$style;duration=$duration;heatSpoken=$false}
 $script:pendingPoke=$null
 $script:quietUntil=$t+$duration+(Get-ActivitySeconds $returnMode)
 $script:nextCamera=$t+$script:rng.Next(120,241)
 Say-Random $kind
}
function Get-CameraFrame([string]$kind,[double]$age,[int]$ReelsStyle=0) {
 if ($kind -eq 'noodles') { return Get-NoodlesFrame $age }
 if ($kind -eq 'hairHeart') { return Get-HairHeartFrame $age }
 if ($kind -eq 'smoke') { return Get-SmokeFrame $age }
 if ($kind -eq 'selfie') {
  if ($age -lt 0.45) { return 0 }
  if ($age -lt 1.1) { return 1 }
  if ($age -lt 1.9) { return 2 }
  return 3
 }
 $first=4+$ReelsStyle*4
 if ($age -lt 0.4) { return $first }
 if ($ReelsStyle -eq 3) {
  if ($age -lt 1.0) { return $first+1 }
  if ($age -lt 1.9) { return $first+2 }
  return $first+3
 }
 if ($age -ge 2.45) { return $first+3 }
 $beat=@(0.28,0.34,0.22)[$ReelsStyle]
 return $first+1+([int][Math]::Floor(($age-0.4)/$beat)%2)
}
function Render-CameraScene([double]$t) {
 if ($null -eq $script:cameraScene) { return }
 if ($script:dragging) { $script:cameraScene=$null; return }
 $scene=$script:cameraScene; $age=$t-$scene.start
 if ($age -ge $scene.duration) {
  $script:cameraScene=$null
  if (-not $script:chaosEnabled) { Set-Pose $scene.returnMode }
  return
 }
 $frameAge=if ($scene.kind -in @('smoke','hairHeart','noodles')) {$age*3.0/$scene.duration} else {$age}
 $frame=Get-CameraFrame $scene.kind $frameAge $scene.style
 if (-not $script:motion) { $frame=switch ($scene.kind) {'selfie' {1}; 'smoke' {0}; 'hairHeart' {4}; 'noodles' {0}; default {4+$scene.style*4}} }
 $script:pet.Source=switch ($scene.kind) {'smoke' {$script:smokeSprites[$frame]}; 'hairHeart' {$script:hairHeartSprites[$frame]}; 'noodles' {$script:noodlesSprites[$frame]}; default {$script:cameraSprites[$frame]}}
 if ($scene.kind -eq 'hairHeart' -and $script:visualStyle -eq '3d' -and $script:motion) {
  $starts=@(0,0.4,0.8,1.2,1.6,2.55); $ends=@(0.4,0.8,1.2,1.6,2.55,3.0)
  $sub=if ($frame -lt 5) {[Math]::Min(3,[Math]::Max(0,[Math]::Floor(($frameAge-$starts[$frame])/($ends[$frame]-$starts[$frame])*4)))} else {0}
  $script:pet.Source=$script:heartSmoothSprites[($frame*4+$sub)]
 }
 if ($scene.kind -eq 'noodles' -and $scene.lastFrame -ne $frame) {
  $scene.previousFrameSource=$scene.lastFrameSource
  $scene.lastFrame=$frame; $scene.frameChanged=$t; $scene.lastFrameSource=$script:pet.Source
 }
 if ($scene.kind -eq 'noodles' -and $frameAge -ge 0.95 -and -not $scene.heatSpoken) {
  $scene.heatSpoken=$true
  if ($script:motion -and $t -ge $script:attentionEnd -and $null -eq $script:pendingPoke) { Say '아 안 매운 줄.' }
 }
 $script:pet.Opacity=1
 $script:restBlend.Visibility='Hidden'; $script:sleepMark.Visibility='Hidden'; $script:fallingPhone.Visibility='Hidden'
 $tr=$script:pet.RenderTransform.Children
 $tr[0].ScaleX=1; $tr[0].ScaleY=1; $tr[1].Angle=0; $tr[2].X=0; $tr[2].Y=0; $tr[3].AngleX=0
 if ($script:motion -and $age -lt 0.18) {
  $p=$age/0.18; $script:restBlend.Source=$scene.previous
  $script:restBlend.Opacity=1-$p; $script:restBlend.Visibility='Visible'; $script:pet.Opacity=$p
 }
 elseif ($script:motion -and $scene.kind -eq 'noodles' -and $null -ne $scene.previousFrameSource) {
  $p=[Math]::Min(1.0,[Math]::Max(0.0,($t-$scene.frameChanged)/0.14))
  if ($p -lt 1) {
   $script:restBlend.Source=$scene.previousFrameSource; $script:restBlend.Opacity=1-$p
   $script:restBlend.Visibility='Visible'; $script:pet.Opacity=$p
  }
 }
 if ($script:motion -and $scene.kind -eq 'reels' -and $age -ge 0.4 -and $age -lt 2.45) {
  $beat=@(0.28,0.34,0.22,0.4)[$scene.style]
  $bounce=@(2.0,0.6,1.2,0.0)[$scene.style]
  $tr[2].Y=-$bounce*[Math]::Abs([Math]::Sin(($age-0.4)*[Math]::PI/$beat))
 }
 if ($script:motion -and $scene.kind -eq 'noodles' -and $frame -eq 3) {
  $tr[1].Angle=0.7*[Math]::Sin($age*16)
 }
 [Windows.Controls.Canvas]::SetTop($script:groundShadow,241)
}
function Get-NextChaosAction {
 $choices=@('selfie','reels','smoke','hairHeart','noodles','run','banana','phone','drop','sleep','game' | Where-Object { $_ -ne $script:chaosLast })
 $script:chaosLast=$choices[$script:rng.Next($choices.Count)]
 return $script:chaosLast
}
function Start-ChaosAction([string]$action,[double]$t) {
 Set-Pose 0 -Immediate
 $script:pendingPoke=$null; $script:pokeScene=$null
 $script:chaosNext=$t+3
 $script:quietUntil=$t+10
 switch ($action) {
  'selfie' { Start-CameraScene 'selfie' $t }
  'reels' { Start-CameraScene 'reels' $t }
  'smoke' { Start-CameraScene 'smoke' $t }
  'hairHeart' { Start-CameraScene 'hairHeart' $t }
  'noodles' { Start-CameraScene 'noodles' $t }
  'run' {
   $script:roamEnabled=$true
   Keep-OnScreen
   $area=[Windows.SystemParameters]::WorkArea
   $route=New-ChaosRoute $script:window.Left $script:window.Top $area.Left $area.Top ($area.Right-$script:window.Width) ($area.Bottom-$script:window.Height) $script:window.Width
   $point=Get-RoutePosition $route 0
   $script:roam=@{start=$t-1.1;fromX=$script:window.Left;toX=$route.endX;toY=$route.endY;route=$route;seconds=3.0;direction=$(if ($point.direction -ne 0) {$point.direction} else {1});crossing=$true;pausedAt=$null;pauseUntil=0.0;frameIndex=0;strideY=0.0;strideAngle=0.0}
   Say '나 저쪽 갔다 올게.'
  }
  'banana' { Set-Pose 0 -Immediate; Say-Random }
  'phone' { Set-Pose 1; Say-Random }
  'drop' { Set-Pose 1 -Immediate; Start-PhoneDrop $t }
  'sleep' { Set-Pose 2; Say '아 몰라. 나 누울래.' }
  'game' { Set-Pose 3 -Immediate; Say-Random }
 }
 $script:bubbleUntil=[DateTime]::Now.AddSeconds(2.7)
}
function Set-ChaosEnabled([bool]$enabled,[switch]$Quiet) {
 if ($script:chaosEnabled -eq $enabled) { return }
 $t=$script:clock.Elapsed.TotalSeconds
 if ($enabled) {
  $script:chaosSaved=@{auto=$script:auto;motion=$script:motion;roamEnabled=$script:roamEnabled;mode=$script:mode}
  $script:chaosEnabled=$true; $script:motion=$true; $script:auto=$false
  $script:chaosLast=''
  Start-ChaosAction (Get-NextChaosAction) $t
 } else {
  $script:chaosEnabled=$false
  Keep-OnScreen
  $saved=$script:chaosSaved
  $script:cameraScene=$null; $script:pokeScene=$null; $script:pendingPoke=$null
  Set-Pose $saved.mode -Immediate
  $script:auto=$saved.auto; $script:motion=$saved.motion; $script:roamEnabled=$saved.roamEnabled
  foreach ($name in @('nextRest','nextRoam','nextDrop','nextExpression','nextBack','nextCamera')) {
   Set-Variable -Name $name -Scope Script -Value ($t+$script:rng.Next(120,241))
  }
  $script:quietUntil=$t+3
  if (-not $Quiet) { Say '휴. 이제 쫌 쉬자.' }
 }
 if ($null -ne $script:chaosMenu) { $script:chaosMenu.IsChecked=$enabled }
}
function Update-Chaos([double]$t) {
 if (-not $script:chaosEnabled -or $script:pet.ContextMenu.IsOpen) { return }
 # Dragging and a clicked glance have priority; never queue missed actions.
 if ($script:pressed -or $script:dragging -or $t -lt $script:attentionEnd -or $t -lt $script:sulkEnd) {
  $script:chaosNext=[Math]::Max($script:chaosNext,$t+0.1); return
 }
 if ($t -lt $script:chaosNext) { return }
 # Finish a crossing exactly at the edge before starting the next action.
 if ($null -ne $script:roam) {
  Update-Roam $t
  if ($null -ne $script:roam -and ($null -ne $script:roam.pausedAt -or $t-$script:roam.start-1.1 -lt $script:roam.seconds)) { return }
 }
 Start-ChaosAction (Get-NextChaosAction) $t
}
function Start-RepeatPoke([double]$t) {
 if ($t-$script:lastPokeAt -le 1.5) { $script:pokeCount++ } else { $script:pokeCount=1 }
 $script:lastPokeAt=$t
 if ($script:pokeCount -lt 3 -or $script:mode -eq 2 -or $null -ne $script:roam -or $null -ne $script:backTurn -or $null -ne $script:cameraScene) { return $false }
 $kind=$script:pokeCount%3
 $script:pokeScene=@{start=$t;kind=$kind}
 $script:attentionStart=$t; $script:attentionEnd=$t+1.1
 Say-Random 'repeatPoke' -Poke
 return $true
}
function Render-RepeatPoke([double]$t) {
 if ($null -eq $script:pokeScene) { return }
 $age=$t-$script:pokeScene.start
 if ($age -ge 1.1 -or $script:dragging -or $null -ne $script:roam -or $null -ne $script:cameraScene) { $script:pokeScene=$null; return }
 if (-not $script:motion -or $null -ne $script:pendingPoke) { return }
 $tr=$script:pet.RenderTransform.Children
 switch ($script:pokeScene.kind) {
  0 { $script:pet.Source=$script:playfulSprites[$script:mode] }
  1 { $script:pet.Source=$script:lookSprites[$script:mode]; $tr[1].Angle=2*[Math]::Sin($age*[Math]::PI/1.1) }
  2 { $script:pet.Source=$script:blinkSprites[$script:mode]; $tr[1].Angle=1.5*[Math]::Sin($age*10)*[Math]::Sin($age*[Math]::PI/1.1) }
 }
}
