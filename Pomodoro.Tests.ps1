function Invoke-PomodoroSelfTest {
 $originalLeft=$window.Left; $originalTop=$window.Top
 $now=[DateTime]::UtcNow
 $invalidRejected=$false
 try { Start-Pomodoro 0 5 4 $now } catch { $invalidRejected=$true }
 if (-not $invalidRejected) { throw 'Pomodoro must reject invalid durations' }
 Start-Pomodoro 1 1 2 $now
 if ($script:pomodoro.deadline -ne $now.AddSeconds(60)) { throw 'Custom focus duration ignored' }
 if ((Get-PomodoroRemaining $now.AddSeconds(1)) -notlike '*59초*') { throw 'Remaining seconds must not round down to zero minutes' }
 Update-Pomodoro $now.AddSeconds(60)
 if ($script:pomodoro.phase -ne 'rest' -or $script:pomodoro.deadline -ne $now.AddSeconds(120)) { throw 'Focus must advance to the configured break' }
 Update-Pomodoro $now.AddSeconds(120)
 if ($script:pomodoro.phase -ne 'focus' -or $script:pomodoro.round -ne 2) { throw 'Break must advance to the next focus round' }
 Update-Pomodoro $now.AddSeconds(180)
 if ($null -ne $script:pomodoro -or $words.Text -notlike '*다 끝났다*') { throw 'Final focus must finish the session' }
 Start-Pomodoro 1 1 2 $now
 Toggle-PomodoroPause $now.AddSeconds(20)
 Update-Pomodoro $now.AddHours(1)
 if (-not $script:pomodoro.paused -or $script:pomodoro.remaining -ne 40) { throw 'Pause must freeze the remaining duration' }
 Toggle-PomodoroPause $now.AddSeconds(100)
 if ($script:pomodoro.deadline -ne $now.AddSeconds(140) -or $script:pomodoro.paused) { throw 'Resume must preserve the exact remaining duration' }
 Start-Pomodoro 1 1 2 $now
 Toggle-PetVisibility
 $deadline=$script:pomodoro.deadline
 Update-Pomodoro $now.AddSeconds(60)
 if ($null -eq $script:pendingPomoNotice -or $script:window.IsVisible) { throw 'Hidden timer must defer its notification' }
 Toggle-PetVisibility
 if ($null -ne $script:pendingPomoNotice -or $script:pomodoro.deadline -ne $deadline.AddSeconds(60)) { throw 'Showing the pet must preserve the timer and deliver the notice' }
 Start-Pomodoro 1 1 2 $now
 Update-Pomodoro $now.AddHours(2)
 if ($null -ne $script:pomodoro) { throw 'Long sleep must catch up without restarting expired phases' }
 Set-Pose 1 -Immediate
 Start-Pomodoro 25 5 4
 $currentMode=$script:mode
 React-ToPoke 4000
 if ($words.Text -notlike '집중 25분*' -or $null -eq $script:pendingPoke) { throw 'Click must show remaining time before the ordinary dialogue' }
 $original=$script:pendingPoke.message; $due=$script:pendingPoke.due
 Update-PokeFollowup $due.AddMilliseconds(-1)
 if ($words.Text -eq $original) { throw 'Ordinary dialogue appeared before the timer message could be read' }
 Update-PokeFollowup $due
 if ($words.Text -ne $original -or $script:mode -ne $currentMode -or $null -ne $script:pendingPoke) { throw 'Ordinary dialogue must follow once without changing the activity' }
 React-ToPoke 4001
 Say '못 본 척 해줘~~'
 Update-PokeFollowup ([DateTime]::UtcNow.AddSeconds(3))
 if ($words.Text -ne '못 본 척 해줘~~') { throw 'Stale dialogue must not overwrite a newer reaction' }
 Set-Pose 0 -Immediate
 $script:roamEnabled=$true
 Start-Roam 5000
 Update-Roam 5002
 React-ToPoke 5002
 Update-Roam 5003.01
 if ($null -ne $script:roam.pausedAt -or $words.Text -notlike '집중*') { throw 'Walking must resume after one second while the timer message remains readable' }
 Update-PokeFollowup $script:pendingPoke.due
 if ($words.Text -ne '왜? 뭐? 산책하는 끼끼 처음 봐?') { throw 'Walking dialogue must follow the timer without another stop' }
 Stop-Roam 5004
 Stop-Pomodoro -Quiet
 Say-Poke '응? 나 불렀어?'
 if ($words.Text -ne '응? 나 불렀어?' -or $null -ne $script:pendingPoke) { throw 'Inactive timer must not delay ordinary dialogue' }
 $settingsDialog=New-PomodoroSettingsDialog
 $script:pomoDialog=$settingsDialog
 $settingsDialog.FindName('FocusMinutes').Text='아무거나'
 $settingsDialog.FindName('StartPomo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if ($null -ne $script:pomodoro -or [string]::IsNullOrEmpty($settingsDialog.FindName('PomoError').Text)) { throw 'Settings dialog must reject invalid input inline' }
 $settingsDialog.FindName('FocusMinutes').Text='7'
 $settingsDialog.FindName('RestMinutes').Text='2'
 $settingsDialog.FindName('RoundCount').Text='2'
 $settingsDialog.FindName('StartPomo').RaiseEvent([Windows.RoutedEventArgs]::new([Windows.Controls.Button]::ClickEvent))
 if ($script:pomodoro.focusSeconds -ne 420 -or $script:pomodoro.restSeconds -ne 120 -or $script:pomodoro.rounds -ne 2) { throw 'Settings dialog must apply the entered durations and round count' }
 $script:pomoDialog=$null
 Stop-Pomodoro -Quiet
 $window.Left=$originalLeft; $window.Top=$originalTop
 Write-Output 'PASS: configurable Pomodoro; focus/break rounds; pause/resume; hidden and overdue timers; timer-first click then contextual dialogue; uninterrupted walking; stale speech cancellation.'
}
