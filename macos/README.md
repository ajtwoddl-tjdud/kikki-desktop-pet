# 끼끼 macOS 개발

macOS 12 이상을 대상으로 하는 Swift/AppKit 앱입니다. 외부 패키지 없이 Xcode Command Line Tools로 빌드합니다.

```bash
bash macos/build.sh
open outputs/macos/Kikki.app
```

출력은 `outputs/macos/Kikki.app`, `outputs/macos/Kikki-macOS.zip`입니다. `build.sh`는 두 CPU 아키텍처를 컴파일하고, Universal 바이너리·plist·임시 서명을 검증한 뒤 호스트 아키텍처로 자체 검사를 실행합니다. 검사 실패 시 ZIP을 만들지 않습니다. 로컬 산출물은 Git에 포함하지 않습니다.

개발 시 `Start-Mac.command`를 사용하면 기존 Kikki를 종료하고 현재 CPU용 앱만 빌드·검사해 `outputs/macos-dev/Kikki.app`을 실행합니다. 빌드만 하려면 `bash macos/build.sh --native`를 사용하세요. Universal ZIP은 배포가 필요할 때 기본 빌드 명령으로 생성합니다.

`PetState.swift`가 활동과 장면 시간, 산책, 수업 타이머를 관리합니다. 숨김 중에는 장면 시간을 멈추고 수업 마감은 실제 날짜로 확인합니다. `Sprites.swift`는 Windows판의 동일한 PNG 시트와 비정형 칸 경계를 읽습니다. `PetView.swift`가 그리기와 마우스 입력을 담당하고, `App.swift`가 투명 비활성 패널·메뉴 막대·Control+M·모니터 영역을 연결합니다. 실행에 네트워크, 계정, 접근성 권한은 필요하지 않습니다.

## 수동 확인

2026-10-16 검증 환경은 Apple Silicon, macOS 26.5.1, Swift 6.2.3입니다. 두 아키텍처 빌드·최소 OS 12.0 설정·서명 검증, 네이티브와 Rosetta 자체 검사 각 528개가 통과했습니다. 실제 UI에서 캐릭터·말풍선, 클릭 반응, 우클릭 활동 선택, 메뉴 숨김·재실행 복귀와 단일 프로세스 유지, 수업 타이머 시작·남은 시간 표시를 확인했습니다. 킹받기 조절의 기본·순한맛·끄기 선택, 재실행 후 순한맛 체크 유지, 끄기 상태의 평소 클릭 대사, 게임 클릭 시 밈 대사와 메롱 표정도 확인했습니다. 최적화의 측정값과 검증은 [OPTIMIZATION.md](../OPTIMIZATION.md)를 참고하세요.

Intel 실기기와 macOS 12~15는 실행 검증하지 않았습니다. Control+M 등록은 성공했으나 자동화 키 입력으로는 콜백을 확인하지 못했고, 드래그 도구는 `AXError.notImplemented`를 반환했습니다. 따라서 실제 키보드 단축키와 마우스 드래그·멀티 모니터·전체 화면 표시는 아래 수동 확인 대상으로 남습니다. Windows WPF 자체 검사는 이 Mac에서 실행하지 않았습니다.

각 지원 OS·CPU의 실제 UI에서 다음을 확인합니다. 자체 검사 통과만으로 이 항목의 통과를 주장하지 않습니다.

- 다른 앱을 입력 중일 때 끼끼가 포커스를 가져가지 않고, 투명 여백을 클릭하면 아래 앱이 반응하는지
- 네 활동의 그림과 말풍선, 클릭 반응, 드래그와 위로 들어올리기·놓기, 우클릭·트랙패드 메뉴
- 산책 도중 클릭 시 현재 발 자세를 유지하고 다시 걷는지, 화면 끝에서 멈추는지
- 메뉴로 폰 떨어뜨리기·줍기, 자세 고치기, 등 돌린 뒤 클릭 반응, 윙크·메롱, 움직임 줄이기, 크기 변경
- 다른 앱이 활성화된 상태에서 Control+M 숨김·복귀, 메뉴 막대 대체 조작, 앱 재실행 시 중복 생성 방지
- 킹받기 조절의 세 단계, 재실행 후 설정 유지, 순한맛 빈도·끄기 상태의 평소 대사
- 수업 카테고리가 메뉴에 노출되지 않는지 확인
- 외부 모니터로 옮긴 뒤 산책·크기 변경, 모니터 분리 후 복귀, Dock 위치·디스플레이 배율 변경
- Spaces·전체 화면·Stage Manager에서의 표시와 메뉴 접근

## 배포

로컬 빌드가 앱과 ZIP을 생성합니다. GitHub Actions나 자동 릴리스는 사용하지 않습니다. 인터넷 배포 전에는 Universal 앱을 Developer ID로 서명·공증하는 별도 릴리스 과정이 필요합니다. 로컬 임시 서명만으로 Gatekeeper 검증을 통과했다고 간주하지 마세요.

플랫폼 참고: [Apple의 Universal 바이너리 안내](https://developer.apple.com/documentation/apple-silicon/building-a-universal-macos-binary), [AppKit 전체 화면 보조 창](https://developer.apple.com/documentation/appkit/nswindow/collectionbehavior-swift.struct/fullscreenauxiliary).


## 2D / 3D 표시

우클릭 또는 메뉴 막대 🐒 → **끼끼 모습 · 2D / 3D**에서 전환합니다. 선택은 `visualStyle` 설정에 저장됩니다. 새로 설치하면 2D로 시작합니다. 앱에 번들된 Blender 렌더 프레임을 사용하므로 별도 Blender 실행은 필요하지 않습니다.

**특별 동작** 메뉴의 셀카·릴스·하트·라면·흡연·심벌즈·스트레칭도 두 모드에서 재생됩니다. 이 메뉴의 클립은 자동 동작으로 등록되지 않으며, 심벌즈 소리는 Mac에 추가하지 않았습니다.

검사: `bash macos/build.sh --native`는 전체 3D 프레임 로딩·투명 여백·전환 즉시 갱신·동작 유지·숨김 중 일시 정지를 검사합니다. `KIKKI_PREVIEW_DIR=/절대/경로 bash macos/build.sh --native`로 앱 렌더러의 2D/3D 기본 동작 PNG도 저장할 수 있습니다.

3D 자세 전환은 13개 실제 중간 포즈를 사용해 0.07초마다 갱신합니다. 자동 행동 간격은 2D와 동일합니다. 모드 변경 중인 전환도 경과 비율을 유지합니다.
