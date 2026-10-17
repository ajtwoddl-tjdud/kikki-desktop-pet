$script:pomodoro=$null
$script:pomoSettings=@{focus=25;rest=5;rounds=4}
$script:pendingPomoNotice=$null
$script:pendingPoke=$null
$script:pomoTimer=New-Object Windows.Threading.DispatcherTimer
$script:pomoTimer.Add_Tick({
 $script:pomoTimer.Stop()
 Update-Pomodoro
 Sync-PomodoroTimer
})
function Sync-PomodoroTimer {
 $script:pomoTimer.Stop()
 if ($null -ne $script:pomodoro -and -not $script:pomodoro.paused) {
  $delay=[Math]::Max(1.0,($script:pomodoro.deadline-[DateTime]::UtcNow).TotalMilliseconds)
  $script:pomoTimer.Interval=[TimeSpan]::FromMilliseconds($delay)
  $script:pomoTimer.Start()
 }
}
function Start-Pomodoro([int]$Focus,[int]$Rest,[int]$Rounds,[datetime]$Now=[DateTime]::UtcNow) {
 if ($Focus -lt 1 -or $Focus -gt 240 -or $Rest -lt 1 -or $Rest -gt 120 -or $Rounds -lt 1 -or $Rounds -gt 12) { throw 'Invalid Pomodoro settings' }
 $script:pomoSettings=@{focus=$Focus;rest=$Rest;rounds=$Rounds}
 $script:pomodoro=@{phase='focus';round=1;rounds=$Rounds;focusSeconds=$Focus*60;restSeconds=$Rest*60;deadline=$Now.AddMinutes($Focus);paused=$false;remaining=0.0}
 $script:classEnd=$null; $script:pendingClassEnd=$false
 $script:pendingPomoNotice=$null
 Say ('집중 {0}분 시작! 끝나면 내가 알려줄게.' -f $Focus)
 Sync-PomodoroTimer
 if ($null -ne $script:classTimer) { Sync-PetTimers }
}
function Stop-Pomodoro([switch]$Quiet) {
 $script:pomodoro=$null; $script:pendingPomoNotice=$null; $script:pendingPoke=$null
 Sync-PomodoroTimer
 if (-not $Quiet) { Say '타이머 껐어. 쪼끔 쉬자.' }
}
function Get-PomodoroRemaining([datetime]$Now=[DateTime]::UtcNow) {
 if ($null -eq $script:pomodoro) { return $null }
 $p=$script:pomodoro
 $seconds=if ($p.paused) { $p.remaining } else { [Math]::Max(0.0,($p.deadline-$Now).TotalSeconds) }
 $phase=if ($p.phase -eq 'focus') { '집중' } else { '휴식' }
 $prompt=if ($p.paused) { '잠깐 멈춰뒀어. '+$phase+' ' } elseif ($p.phase -eq 'focus') { '집중해. ' } else { '좀 쉬어. ' }
 if ($seconds -le 60) { return ('{0}{1}초 남았어.' -f $prompt,[int][Math]::Ceiling($seconds)) }
 return ('{0}{1}분 남았어.' -f $prompt,[int][Math]::Ceiling($seconds/60.0))
}
function Toggle-PomodoroPause([datetime]$Now=[DateTime]::UtcNow) {
 if ($null -eq $script:pomodoro) { Say '돌아가는 타이머는 없어. 먼저 시작해 줘.'; return }
 Update-Pomodoro $Now
 if ($null -eq $script:pomodoro) { return }
 $p=$script:pomodoro
 if ($p.paused) {
  $p.deadline=$Now.AddSeconds($p.remaining); $p.paused=$false
  Say ('다시 시작! '+(Get-PomodoroRemaining $Now))
 } else {
  $p.remaining=[Math]::Max(0.0,($p.deadline-$Now).TotalSeconds); $p.paused=$true
  Say (Get-PomodoroRemaining $Now)
 }
 Sync-PomodoroTimer
}
function Present-PomodoroNotice {
 if ($null -ne $script:pendingPomoNotice -and $script:window.IsVisible) {
  $notice=$script:pendingPomoNotice; $script:pendingPomoNotice=$null
  Say $notice; $script:bubbleUntil=[DateTime]::Now.AddSeconds(10)
 }
}
function Update-Pomodoro([datetime]$Now=[DateTime]::UtcNow) {
 if ($null -eq $script:pomodoro -or $script:pomodoro.paused) { return }
 $notice=$null
 while ($null -ne $script:pomodoro -and $Now -ge $script:pomodoro.deadline) {
  $p=$script:pomodoro
  if ($p.phase -eq 'focus') {
   if ($p.round -ge $p.rounds) {
    $notice=('집중 {0}번 다 끝났다! 고생했어. 이제 푹 쉬자.' -f $p.rounds)
    $script:pomodoro=$null
   } else {
    $p.phase='rest'; $p.deadline=$p.deadline.AddSeconds($p.restSeconds)
    $notice=('집중 끝! {0}분 쉬자. 나랑 쪼끔 쉬어.' -f $script:pomoSettings.rest)
   }
  } else {
   $p.round++; $p.phase='focus'; $p.deadline=$p.deadline.AddSeconds($p.focusSeconds)
   $notice=('휴식 끝! {0}번째 집중 시작이야. {1}분 뒤에 보자.' -f $p.round,$script:pomoSettings.focus)
  }
 }
 if ($null -ne $notice) {
  $script:pendingPomoNotice=$notice
  Present-PomodoroNotice
  Sync-PomodoroTimer
 }
}
function Get-PomodoroPokeReply([string]$Fallback,[int]$Roll=-1) {
 if ($null -eq $script:pomodoro -or $script:pomodoro.phase -ne 'focus' -or $script:pomodoro.paused) { return $Fallback }
 $chance=switch ($script:mischiefLevel) { 'normal' {60} 'mild' {20} default {0} }
 if ($Roll -lt 0) { $Roll=$script:rng.Next(100) }
 if ($Roll -ge $chance) { return $Fallback }
 $choices=@('넌 빨리 공부해~ 난 여기 있을게.', '나 누를 시간에 한 줄 더 읽어~', '공부는 네가 해. 귀여운 건 내가 할게.', '나 그만 봐~ 나도 공부하는 줄 알겠어.', '넌 빨리 공부해~ 나는 원래 이러고 살아.', '나한테 딴짓하러 왔지? 쪼끔만 보고 돌아가~')
 $activityLines=if ($null -ne $script:cameraScene) {
  if ($script:cameraScene.kind -eq 'selfie') {
   @('너도 찍어줄게. 공부 끝나면~','난 사진 찍을게. 넌 공부해~','나 구경은 쉬는 시간에~')
  } else {
   @('내 춤 구경은 쉬는 시간에 해~','넌 공부해. 춤은 내가 출게~','같이 놀려면 공부부터 끝내고 와~')
  }
 } elseif ($null -ne $script:roam) {
  @('난 산책할게. 넌 공부하고 있어~','내가 걷는 동안 넌 쪼끔 더 해~','끼끼는 산책 중. 너는 집중 중이잖아~','나 따라오지 말고 할 거 마저 해~','나 산책 갔다 올 때까지 쫌 해놔~')
 } elseif ($null -ne $script:backTurn) {
  @('난 여기서 쉴게. 넌 공부해~','고개 돌려줬다. 이제 공부하러 가~','나 안 갔어. 집중 끝날 때까지 여기 있을게.','내 뒤통수 말고 할 거 봐~','등 돌려도 네가 딴짓하는 건 알지~')
 } else {
  switch ($script:mode) {
   0 { @('난 바나나 먹을게. 넌 빨리 공부해~','나는 한 입 더. 너는 한 줄 더~','내 간식 시간이지, 네 쉬는 시간은 아직 아니야~','나 씹는 동안 쪼끔만 더 해~','너도 다 하면 간식 먹자. 아직은 말고~') }
   1 { @('난 폰 봐도 돼. 넌 집중해~','내 폰 같이 보러 온 거야? 아직 쉬는 시간 아니지~','나만 누워 있는 거야. 넌 공부 마저 해~','너까지 폰 보러 가면 안 되는데~','난 누워서 기다릴게. 끝나면 불러~') }
   2 { @('난 쪼끔 잘게… 넌 공부해~','나 깨울 시간에 쪼끔만 더 해…','난 자도 돼… 넌 아직 집중 시간이잖아~','끝나면 깨워… 지금은 공부해~','내가 눈 감고 있어도 딴짓하면 안 된다…') }
   3 { @('난 한 판 더. 넌 한 줄 더~','내 게임 구경은 쉬는 시간에 해~','나는 컨트롤러 보고, 너는 할 거 보고~','공부 끝나면 놀아줄게. 지금은 안 돼~','난 노는 데 집중할게. 넌 공부에 집중해~') }
  }
 }
 $choices+=@($activityLines)
 $remaining=($script:pomodoro.deadline-[DateTime]::UtcNow).TotalSeconds
 if ($remaining -le 60) { $choices+=@('이제 쪼끔 남았어. 마저 하고 같이 쉬자~','곧 끝나는데 나 누르고 있네~ 쪼끔만 더 해.') }
 elseif ($script:pomodoro.focusSeconds-$remaining -lt 60) { $choices+=@('방금 시작했잖아. 벌써 끼끼 보러 왔어?','시작한 지 얼마 안 됐는데~ 쪼끔만 집중해.') }
 $available=@($choices | Where-Object { -not $script:recentLines.Contains($_) })
 if ($available.Count -eq 0) { $available=$choices }
 return $available[$script:rng.Next($available.Count)]
}
function Say-Poke([string]$Message) {
 Update-Pomodoro
 if ($null -eq $script:pomodoro) { Say $Message; return }
 Say (Get-PomodoroRemaining)
 $reply=Get-PomodoroPokeReply $Message
 $script:pendingPoke=@{message=$reply;pomoTease=($reply -ne $Message);due=[DateTime]::UtcNow.AddSeconds(1.6);mode=$script:mode;roam=$script:roam;back=$script:backTurn}
 $script:bubbleUntil=[DateTime]::Now.AddSeconds(5)
}
function Update-PokeFollowup([datetime]$Now=[DateTime]::UtcNow) {
 if ($null -eq $script:pendingPoke -or $Now -lt $script:pendingPoke.due) { return }
 $queued=$script:pendingPoke; $script:pendingPoke=$null
 if (-not $script:window.IsVisible -or $script:dragging -or $script:pressed -or $queued.mode -ne $script:mode) { return }
 if (-not [Object]::ReferenceEquals($queued.roam,$script:roam) -or -not [Object]::ReferenceEquals($queued.back,$script:backTurn)) { return }
 Say $queued.message
 if (($queued.memeFace -or $queued.pomoTease) -and $script:motion -and $script:mischiefLevel -eq 'normal' -and $script:mode -ne 2) { $script:memeFaceEnd=$script:clock.Elapsed.TotalSeconds+1.15 }
 $script:bubbleUntil=[DateTime]::Now.AddSeconds(3)
}
function New-PomodoroSettingsDialog {
 [xml]$pomoXaml=@'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml" Title="끼끼 뽀모도로" Width="360" SizeToContent="Height" ResizeMode="NoResize" WindowStartupLocation="CenterScreen" Background="#FFFEF8" FontFamily="Malgun Gothic" FontSize="14" ShowInTaskbar="False" Topmost="True">
 <StackPanel Margin="24">
  <TextBlock Text="같이 집중하고, 같이 쉬자." FontSize="19" FontWeight="Bold" Foreground="#493020" Margin="0,0,0,8"/>
  <TextBlock Text="시간은 네가 정해. 끼끼를 톡 누르면 남은 시간을 먼저 알려줄게." TextWrapping="Wrap" Foreground="#75614F" Margin="0,0,0,20"/>
  <Grid>
   <Grid.ColumnDefinitions><ColumnDefinition Width="*"/><ColumnDefinition Width="90"/></Grid.ColumnDefinitions>
   <Grid.RowDefinitions><RowDefinition Height="44"/><RowDefinition Height="44"/><RowDefinition Height="44"/></Grid.RowDefinitions>
   <TextBlock Text="집중 시간 (분)" VerticalAlignment="Center"/>
   <TextBox x:Name="FocusMinutes" Grid.Column="1" Margin="0,5" Padding="7,3" VerticalContentAlignment="Center"/>
   <TextBlock Text="휴식 시간 (분)" Grid.Row="1" VerticalAlignment="Center"/>
   <TextBox x:Name="RestMinutes" Grid.Row="1" Grid.Column="1" Margin="0,5" Padding="7,3" VerticalContentAlignment="Center"/>
   <TextBlock Text="집중 반복 횟수" Grid.Row="2" VerticalAlignment="Center"/>
   <TextBox x:Name="RoundCount" Grid.Row="2" Grid.Column="1" Margin="0,5" Padding="7,3" VerticalContentAlignment="Center"/>
  </Grid>
  <TextBlock Text="집중 → 휴식을 자동으로 이어가고, 마지막 집중이 끝나면 마칠게." TextWrapping="Wrap" Foreground="#75614F" FontSize="12" Margin="0,14,0,0"/>
  <TextBlock x:Name="PomoError" Foreground="#A33A26" FontSize="12" TextWrapping="Wrap" Margin="0,10,0,10"/>
  <StackPanel Orientation="Horizontal" HorizontalAlignment="Right">
   <Button x:Name="CancelPomo" Content="닫기" Padding="15,7" Margin="0,0,8,0" IsCancel="True"/>
   <Button x:Name="StartPomo" Content="시작" Padding="22,7" IsDefault="True" Background="#EACCA2"/>
  </StackPanel>
 </StackPanel>
</Window>
'@
 $dialog=[Windows.Markup.XamlReader]::Load([System.Xml.XmlNodeReader]::new($pomoXaml))
 $dialog.Owner=$script:window
 $dialog.FindName('FocusMinutes').Text=[string]$script:pomoSettings.focus
 $dialog.FindName('RestMinutes').Text=[string]$script:pomoSettings.rest
 $dialog.FindName('RoundCount').Text=[string]$script:pomoSettings.rounds
 if ($null -ne $script:pomodoro) { $dialog.FindName('StartPomo').Content='새로 시작' }
 $dialog.FindName('CancelPomo').Add_Click({ $script:pomoDialog.Close() })
 $dialog.FindName('StartPomo').Add_Click({
  $d=$script:pomoDialog; $focusValue=0; $restValue=0; $roundValue=0
  $valid=[int]::TryParse($d.FindName('FocusMinutes').Text,[ref]$focusValue)
  $valid=([int]::TryParse($d.FindName('RestMinutes').Text,[ref]$restValue)) -and $valid
  $valid=([int]::TryParse($d.FindName('RoundCount').Text,[ref]$roundValue)) -and $valid
  if (-not $valid -or $focusValue -lt 1 -or $focusValue -gt 240 -or $restValue -lt 1 -or $restValue -gt 120 -or $roundValue -lt 1 -or $roundValue -gt 12) {
   $d.FindName('PomoError').Text='정수로 입력해 줘. 집중 1~240분, 휴식 1~120분, 반복 1~12번까지 가능해.'
   return
  }
  Start-Pomodoro $focusValue $restValue $roundValue
  $d.Close()
 })
 return $dialog
}
function Show-PomodoroSettings {
 $dialog=New-PomodoroSettingsDialog
 $script:pomoDialog=$dialog
 try { [void]$dialog.ShowDialog() } finally { $script:pomoDialog=$null }
}
