# 끼끼 런타임 최적화

2026-10-16, Apple Silicon / macOS 26.5.1 / Swift 6.2.3에서 로컬로 비교했습니다. GitHub Actions는 사용하지 않습니다.

## 식별한 비용과 적용

- 두 플랫폼 모두 숨김 중에도 약 30Hz로 애니메이션 타이머를 호출했습니다. 이제 숨기면 타이머를 중지하고, 수업 타이머가 있으면 종료 시각에만 한 번 호출합니다. Mac은 기존 전역 단축키 콜백으로, Windows는 기존 이름 있는 이벤트를 기다리는 `KikkiEventWatcher`로 다시 표시합니다.
- 일반 활동은 15fps, 산책·들어올리기·폰 떨어뜨리기·자세 전환은 30fps, 움직임 줄이기는 10Hz로 갱신합니다. Mac 메뉴를 연 동안에는 애니메이션을 중지합니다. Mac 반복 타이머에는 10% tolerance를 설정합니다.
- Mac은 실제 그림·말풍선·크기·변형이 바뀔 때만 그립니다. `CGImage`를 직접 그려 매 프레임 `NSImage`를 만드는 과정을 없앴습니다. 글자 높이는 대사가 바뀔 때만 측정하고, 접근성 값도 내용이 바뀔 때만 갱신합니다.
- Windows는 같은 이미지·대사에 대해 말풍선 위치와 크기를 다시 계산하지 않습니다. 기존 WPF 이미지·변형·프레임 캐시는 유지합니다.
- `Start-Mac.command`는 실행 중인 Kikki를 종료하고 현재 CPU용 앱만 빌드해 새 바이너리를 실행합니다. 배포용 `bash macos/build.sh`는 기존처럼 Universal 앱과 ZIP을 만듭니다. 개발 앱은 `outputs/macos-dev`, 배포 앱은 `outputs/macos`로 분리합니다.

Windows 대기는 C#에서 수행하지만 PowerShell 상태 변경은 `DispatcherSynchronizationContext`를 통해 UI 스레드로 돌려보냅니다. 종료 시 대기 등록을 해제하고, 이미 대기열에 들어간 콜백도 실행하지 않습니다. UI 프레임워크와 활동 상태의 소유권은 그대로 유지합니다.

## 비교 결과

동일한 600개 시점을 오프스크린 비트맵에 그렸습니다. 변경 전 소스와 변경 후 소스를 각각 `swiftc -O`로 컴파일하고, 실행 순서를 번갈아 5회씩 측정한 프로세스 CPU 시간의 중앙값입니다. 비트맵은 매번 투명하게 초기화했습니다. 세 시나리오의 마지막 프레임 픽셀 SHA-256이 모두 일치했습니다.

| 장면 | 변경 전 CPU | 변경 후 CPU | 다시 그리기 |
| --- | ---: | ---: | ---: |
| 폰 보기 + 말풍선 | 389.93ms | 391.06ms | 600 → 587 |
| 움직임 줄이기, 정지 화면 | 45.26ms | 0.30ms | 600 → 1 |
| 같은 발 프레임을 유지하는 산책 | 255.99ms | 74.95ms | 600 → 150 |

정지 화면의 그리기 CPU 시간은 약 99.3%, 산책은 약 70.7% 감소했습니다. 계속 호흡하는 장면의 프레임당 비용은 사실상 같았습니다. 이 비교는 같은 30Hz 시점으로 검사하므로, 실제 일반 활동의 30→15fps 조정 효과는 포함하지 않습니다. 배터리 지속 시간·GPU·전체 앱 CPU 감소율을 측정한 결과는 아닙니다.

원시 측정값은 로컬 `outputs/optimization/measurements.json`, 요약은 `outputs/optimization/summary.json`에 있습니다. 검사 코드는 `macos/Benchmarks/main.swift`입니다. 현재 렌더러에서 강제 재그리기와 변경 시 재그리기를 비교하려면 저장소 루트에서 다음을 실행합니다.

```bash
mkdir -p outputs/optimization
xcrun swiftc -swift-version 5 -O macos/Sources/{Mischief,PetState,Sprites,PetView}.swift macos/Benchmarks/main.swift -o outputs/optimization/always-redraw
xcrun swiftc -swift-version 5 -O -D OPTIMIZED macos/Sources/{Mischief,PetState,Sprites,PetView}.swift macos/Benchmarks/main.swift -o outputs/optimization/on-change
outputs/optimization/always-redraw assets
outputs/optimization/on-change assets
```

## 검증과 한계

Mac Universal 빌드·서명 검증과 네이티브·Rosetta 자체 검사 각 528개가 통과했습니다. Windows 공통 런타임의 이벤트 전달·UI 컨텍스트 전환·타이머 정책·해제·활동 선택·산책 도착점과 PowerShell 문법 검사와 대사·설정 저장 검사 226개는 격리된 PowerShell 7.6.7에서 통과했습니다. 검사 도구는 공식 SHA-256을 확인해 임시로 사용한 뒤 삭제했습니다.

실제 Mac 앱 로그에서도 일반 67ms, 움직임 줄이기 100ms, 숨김 시 0(애니메이션 타이머 없음)을 확인했습니다. 숨김 후 8초 동안 `ps` 누적 CPU 시간의 증가는 0.00초였습니다. 이는 해당 짧은 샘플의 측정 정밀도 내 결과이며, CPU 사용이나 OS 이벤트가 항상 0이라는 뜻은 아닙니다.

Windows PowerShell 5.1 / WPF 전체 UI와 실제 Windows CPU·배터리 성능은 이 Mac에서 확인하지 않았습니다. Windows에서는 아래 두 검사를 실행해야 합니다.

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tests\Runtime.SelfTest.ps1
powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Doongi.ps1 -SelfTest
```

첫 검사는 플랫폼 공통 런타임을, 두 번째는 WPF 실제 창과 숨김·복귀 타이머를 검사합니다. `Runtime.ps1`, `Runtime.cs`도 Windows 배포 폴더에 함께 포함해야 합니다.

## Rust 판단

이번 비용은 UI 타이머 호출과 중복 그리기에서 발생했습니다. 작은 활동 정책·산책 수식과 픽셀 경계 계산은 이미 Swift 또는 컴파일된 C#으로 처리하며, Rust로 옮겨도 불필요한 UI 호출은 없어지지 않습니다. 현재는 두 플랫폼의 네이티브 렌더러를 유지하고 Rust·FFI·추가 빌드 도구는 도입하지 않았습니다.

후속 동작 조정에서는 활동·세부 동작·자동 산책을 모두 2~4분 간격으로 맞췄습니다. 자동 산책은 반대쪽 끝을 목적지로 삼습니다. 활동을 바꿔도 산책·세부 동작의 예약 시각을 초기화하지 않고, 밀린 세부 동작은 가장 오래 기다린 종류부터 선택합니다. 세부 동작 사이에도 분 단위 휴식을 두어 한꺼번에 몰리지 않게 했습니다.

참고: [Apple의 Mac 타이머 에너지 지침](https://developer.apple.com/library/archive/documentation/Performance/Conceptual/power_efficiency_guidelines_osx/Timers.html), [Microsoft의 등록 대기 API](https://learn.microsoft.com/en-us/dotnet/api/system.threading.threadpool.registerwaitforsingleobject), [WPF UI 스레드 모델](https://learn.microsoft.com/en-us/dotnet/desktop/wpf/advanced/threading-model).
