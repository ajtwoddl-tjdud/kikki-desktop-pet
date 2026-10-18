function Invoke-PomodoroStoreSelfTest {
 $now=[DateTime]::UtcNow
 $path=Get-PomodoroStatePath
 if ($path -eq (Join-Path ([Environment]::GetFolderPath('ApplicationData')) 'Kikki/pomodoro.json')) { throw 'Self-test attempted to touch the real Pomodoro session' }
 Start-Pomodoro 25 5 4 $now
 $deadline=$script:pomodoro.deadline
 $script:pomodoro=$null; $script:pomoSettings=@{focus=1;rest=1;rounds=1}
 if (-not (Read-PomodoroState) -or $script:pomodoro.deadline -ne $deadline -or $script:pomodoro.phase -ne 'focus' -or $script:pomoSettings.focus -ne 25) { throw 'Restart lost focus deadline or settings' }
 if ((Get-PomodoroRemaining $now.AddMinutes(7)) -notlike '*18분*') { throw 'Restart reset the timer instead of preserving elapsed wall time' }
 Toggle-PomodoroPause $now.AddMinutes(10)
 $script:pomodoro=$null
 if (-not (Read-PomodoroState) -or -not $script:pomodoro.paused -or $script:pomodoro.remaining -ne 900) { throw 'Restart lost the paused timer' }
 Update-Pomodoro $now.AddDays(1)
 if ($script:pomodoro.remaining -ne 900) { throw 'Paused saved timer elapsed while closed' }
 Toggle-PomodoroPause $now.AddDays(1)
 Update-Pomodoro $now.AddDays(1).AddSeconds(900)
 $restDeadline=$script:pomodoro.deadline
 $script:pomodoro=$null
 if (-not (Read-PomodoroState) -or $script:pomodoro.phase -ne 'rest' -or $script:pomodoro.deadline -ne $restDeadline) { throw 'Restart lost the break after a resumed focus' }
 Stop-Pomodoro -Quiet
 $script:pomoSettings=@{focus=1;rest=1;rounds=1}
 if (-not (Read-PomodoroState) -or $null -ne $script:pomodoro -or $script:pomoSettings.focus -ne 25) { throw 'Cancelled timer resurrected or settings disappeared' }
 Start-Pomodoro 1 1 2 $now.AddHours(-3)
 $script:pomodoro=$null
 if (-not (Read-PomodoroState)) { throw 'Expired session could not be recovered' }
 $signals=$script:cymbalSignals
 Update-Pomodoro $now
 if ($null -ne $script:pomodoro -or $script:cymbalSignals -ne $signals+1) { throw 'Restored overdue timer restarted or rang several times' }
 if (-not (Read-PomodoroState) -or $null -ne $script:pomodoro) { throw 'Completed timer resurrected after a second restart' }
 Stop-Pomodoro -Quiet
 [IO.File]::WriteAllText($path,'{"version":99}')
 if (Read-PomodoroState 3>$null) { throw 'Invalid saved state was accepted' }
 if ([IO.File]::Exists($path+'.'+$PID+'.tmp')) { throw 'Atomic Pomodoro save left an unfinished temporary file' }
 [IO.File]::Delete($path)
 if ([IO.File]::Exists($path+'.previous')) { [IO.File]::Delete($path+'.previous') }
 $script:pomoSavedJson=$null
 Write-Output 'PASS: persistent focus/rest deadlines, round/settings restore, pause/resume across restart, expired catch-up, no cancelled/completed resurrection, isolated atomic state files.'
}
