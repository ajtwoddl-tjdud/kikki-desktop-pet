$script:pomodoro=$null
$script:pomoSettings=@{focus=25;rest=5;rounds=4}
$script:pendingPomoNotice=$null
$script:pendingPoke=$null
. (Join-Path $PSScriptRoot 'PomodoroStore.ps1')
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
 Stop-Cymbals
 $script:pomoSettings=@{focus=$Focus;rest=$Rest;rounds=$Rounds}
 $script:pomodoro=@{phase='focus';round=1;rounds=$Rounds;focusSeconds=$Focus*60;restSeconds=$Rest*60;deadline=$Now.AddMinutes($Focus);paused=$false;remaining=0.0}
 $script:classEnd=$null; $script:pendingClassEnd=$false
 $script:pendingPomoNotice=$null
 [void](Save-PomodoroState)
 Say ('집중 {0}분. 끝나면 불러줄게.' -f $Focus)
 Sync-PomodoroTimer
 if ($null -ne $script:classTimer) { Sync-PetTimers }
}
function Stop-Pomodoro([switch]$Quiet) {
 Stop-Cymbals
 $script:pomodoro=$null; $script:pendingPomoNotice=$null; $script:pendingPoke=$null
 [void](Save-PomodoroState)
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
 if ($null -eq $script:pomodoro) { Say '타이머부터 켜줘.'; return }
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
 [void](Save-PomodoroState)
 Sync-PomodoroTimer
}
function Present-PomodoroNotice {
 if ($null -ne $script:pendingPomoNotice -and $script:window.IsVisible) {
  $notice=$script:pendingPomoNotice; $script:pendingPomoNotice=$null
  Say $notice; $script:bubbleUntil=[DateTime]::Now.AddSeconds(10)
  [void](Save-PomodoroState)
 }
}
function Update-Pomodoro([datetime]$Now=[DateTime]::UtcNow) {
 if ($null -eq $script:pomodoro -or $script:pomodoro.paused) { return }
 $notice=$null
 while ($null -ne $script:pomodoro -and $Now -ge $script:pomodoro.deadline) {
  $p=$script:pomodoro
  if ($p.phase -eq 'focus') {
   if ($p.round -ge $p.rounds) {
    $notice=('집중 {0}번 다 끝났다. 이제 쉬자.' -f $p.rounds)
    $script:pomodoro=$null
   } else {
    $p.phase='rest'; $p.deadline=$p.deadline.AddSeconds($p.restSeconds)
    $notice=('집중 끝. {0}분 쉬자.' -f $script:pomoSettings.rest)
   }
  } else {
   $p.round++; $p.phase='focus'; $p.deadline=$p.deadline.AddSeconds($p.focusSeconds)
   $notice=('휴식 끝. {0}번째야. {1}분만 더.' -f $p.round,$script:pomoSettings.focus)
  }
 }
 if ($null -ne $notice) {
  $script:pendingPomoNotice=$notice
  Present-PomodoroNotice
  Request-Cymbals $notice
  [void](Save-PomodoroState)
  Sync-PomodoroTimer
 }
}
function Get-PomodoroPokeReply([string]$Fallback,[int]$Roll=-1) {
 if ($null -eq $script:pomodoro -or $script:pomodoro.phase -ne 'focus' -or $script:pomodoro.paused) { return $Fallback }
 $chance=switch ($script:mischiefLevel) { 'normal' {60} 'mild' {20} default {0} }
 if ($Roll -lt 0) { $Roll=$script:rng.Next(100) }
 if ($Roll -ge $chance) { return $Fallback }
 $choices=@('넌 빨리 공부해~', '나 누를 시간에 한 줄 더 읽어~', '나 그만 보고 공부해~', '왜 왔어. 아직 안 끝났는데.', '끝나면 놀아줄게. 아직은 안 돼.', '나 핑계로 쉬러 왔지.')
 $activityLines=if ($null -ne $script:cameraScene) {
  if ($script:cameraScene.kind -eq 'selfie') {
   @('너도 찍어줄게. 공부 끝나면.','사진 구경은 끝나고 해~','나 구경은 쉬는 시간에.')
  } elseif ($script:cameraScene.kind -eq 'smoke') {
   @('나 그만 보고 공부해~','끝나고 와. 아직 안 됐어.','쉬는 시간 아니잖아~')
  } elseif ($script:cameraScene.kind -eq 'noodles') {
   @('난 먹을게. 넌 공부해~','다 하면 한 입 줄게.','나 매워하는 거 그만 보고 공부해~')
  } elseif ($script:cameraScene.kind -eq 'potty') {
   @('저쪽 봐. 책 있는 쪽.','구경은 됐고. 공부해~','나 말고 책 봐. 지금은 쫌.')
  } elseif ($script:cameraScene.kind -eq 'hairHeart') {
   @('다 하면 줄게. 아직 공부 중이잖아.','이거 보고 공부하러 가~','보고 있지 말고 마저 하고 와.')
  } else {
   @('춤 구경은 끝나고 해~','넌 공부해. 난 찍던 거 마저 찍고.','같이 놀 거면 다 하고 와.')
  }
 } elseif ($null -ne $script:roam) {
  @('나 걷고 올게. 넌 공부해~','나 갔다 올 때까지 쫌 해놔.','따라오지 마. 공부하던 거 마저 해.','구경 그만. 나 안 도망가.','나 올 때까지 한 쪽만 더.')
 } elseif ($null -ne $script:backTurn) {
  @('난 여기 쉴게. 넌 공부해~','응. 봤어. 이제 공부해.','나 안 갔어. 마저 하고 와.','내 뒤통수 말고 책 봐~','또 왔네. 아직 안 끝났는데.')
 } else {
  switch ($script:mode) {
   0 { @('난 먹을게. 넌 공부해~','한 입만 먹고. 넌 한 줄만 더.','아직 안 끝났어. 간식은 이따가.','나 이거 먹는 동안 쫌만 더 해.','다 하면 너도 뭐 먹자.') }
   1 { @('난 폰 봐도 돼. 넌 집중해~','지금 같이 보면 안 되잖아~','너까지 눕지는 마~','넌 폰 내려놔. 아직 안 끝났어.','다 하면 와. 같이 보자.') }
   2 { @('난 잘게… 넌 공부해…','나 깨우지 말고 한 줄 더…','너까지 자는 건 아니지…?','끝나면 깨워…','안 끝났는데 왜 왔어…') }
   3 { @('나 한 판만 더. 넌 한 쪽만 더.','구경은 끝나고 해~','나 말고 책 봐~','다 하면 놀아줄게.','나도 집중 중이야. 넌 공부하고.') }
  }
 }
 $choices+=@($activityLines)
 $remaining=($script:pomodoro.deadline-[DateTime]::UtcNow).TotalSeconds
 if ($remaining -le 60) { $choices+=@('거의 다 했어. 끝나면 같이 쉬자.','쫌만 더 하면 되는데 왜 왔어~') }
 elseif ($script:pomodoro.focusSeconds-$remaining -lt 60) { $choices+=@('방금 시작했잖아. 벌써 왔어?','아직 얼마 안 됐어. 앉아 있어~') }
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
