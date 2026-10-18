$script:pomoSaveError=$null
$script:pomoSavedJson=$null
if ($SelfTest) { $script:pomoTestStore=Join-Path ([IO.Path]::GetTempPath()) ('kikki-pomo-'+[Guid]::NewGuid().ToString('N')+'.json') }
function Get-PomodoroStatePath {
 if ($SelfTest) { return $script:pomoTestStore }
 return Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kikki/pomodoro.json'
}
function Save-PomodoroState {
 $path=Get-PomodoroStatePath
 $temp=$path+'.'+$PID+'.tmp'
 try {
  $session=$null
  if ($null -ne $script:pomodoro) {
   $p=$script:pomodoro
   $remaining=if ($p.paused) {$p.remaining} else {0.0}
   $session=@{phase=$p.phase;round=$p.round;rounds=$p.rounds;focusSeconds=$p.focusSeconds;restSeconds=$p.restSeconds;paused=$p.paused;remaining=$remaining;deadline=$p.deadline.ToUniversalTime().ToString('o')}
  }
  $json=@{version=1;settings=$script:pomoSettings;session=$session;notice=$script:pendingPomoNotice} | ConvertTo-Json -Depth 5 -Compress
  if ($json -eq $script:pomoSavedJson -and [IO.File]::Exists($path)) { return $true }
  [void][IO.Directory]::CreateDirectory([IO.Path]::GetDirectoryName($path))
  [IO.File]::WriteAllText($temp,$json,[Text.UTF8Encoding]::new($false))
  if ([IO.File]::Exists($path)) { [IO.File]::Replace($temp,$path,$path+'.previous') } else { [IO.File]::Move($temp,$path) }
  $script:pomoSavedJson=$json; $script:pomoSaveError=$null
  return $true
 } catch {
  $script:pomoSaveError=$_.Exception.Message
  Write-Warning ('Pomodoro state could not be saved: '+$script:pomoSaveError)
  return $false
 } finally { if ([IO.File]::Exists($temp)) { [IO.File]::Delete($temp) } }
}
function Read-PomodoroInteger($value,[int]$minimum,[int]$maximum) {
 if ($null -eq $value -or $value -is [bool]) { throw 'Missing Pomodoro number' }
 $number=[double]$value
 if ([double]::IsNaN($number) -or [double]::IsInfinity($number) -or $number -lt $minimum -or $number -gt $maximum -or [Math]::Floor($number) -ne $number) { throw 'Invalid saved Pomodoro number' }
 return [int]$number
}
function Read-PomodoroState {
 $path=Get-PomodoroStatePath
 if (-not [IO.File]::Exists($path)) { return $false }
 try {
  $json=[IO.File]::ReadAllText($path)
  if ($json.Length -gt 65536) { throw 'Saved Pomodoro data is too large' }
  $saved=$json | ConvertFrom-Json
  if ($saved.version -ne 1) { throw 'Unsupported Pomodoro state version' }
  $settings=@{focus=(Read-PomodoroInteger $saved.settings.focus 1 240);rest=(Read-PomodoroInteger $saved.settings.rest 1 120);rounds=(Read-PomodoroInteger $saved.settings.rounds 1 12)}
  $session=$null
  if ($null -ne $saved.session) {
   $p=$saved.session
   if ($p.phase -notin @('focus','rest') -or $p.paused -isnot [bool]) { throw 'Invalid saved Pomodoro phase' }
   $rounds=Read-PomodoroInteger $p.rounds 1 12
   $round=Read-PomodoroInteger $p.round 1 $rounds
   $focus=Read-PomodoroInteger $p.focusSeconds 60 14400
   $rest=Read-PomodoroInteger $p.restSeconds 60 7200
   if ($focus -ne $settings.focus*60 -or $rest -ne $settings.rest*60 -or $rounds -ne $settings.rounds) { throw 'Saved session does not match its settings' }
   $remaining=[double]$p.remaining
   $limit=if ($p.phase -eq 'focus') {$focus} else {$rest}
   if ([double]::IsNaN($remaining) -or [double]::IsInfinity($remaining) -or $remaining -lt 0 -or $remaining -gt $limit) { throw 'Invalid paused Pomodoro duration' }
   $deadline=[DateTime]::Parse([string]$p.deadline,[Globalization.CultureInfo]::InvariantCulture,[Globalization.DateTimeStyles]::RoundtripKind).ToUniversalTime()
   $session=@{phase=[string]$p.phase;round=$round;rounds=$rounds;focusSeconds=$focus;restSeconds=$rest;paused=[bool]$p.paused;remaining=$remaining;deadline=$deadline}
  }
  $notice=if ($saved.notice -is [string] -and $saved.notice.Length -le 200) {$saved.notice} else {$null}
  $script:pomoSettings=$settings; $script:pomodoro=$session; $script:pendingPomoNotice=$notice
  $script:pomoSavedJson=$json; $script:pomoSaveError=$null
  Sync-PomodoroTimer
  return $true
 } catch {
  $script:pomoSaveError=$_.Exception.Message
  Write-Warning ('Saved Pomodoro state could not be read: '+$script:pomoSaveError)
  return $false
 }
}
