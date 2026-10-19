# 끼끼 3D 애셋

승인된 끼끼 얼굴·귀·머리카락·꼬리를 사용하고, 동작별 팔·다리·손과 소품을 Blender에서 구성했습니다. `kikki-animation.blend`에는 원본 피규어 장면과 257개 키 포즈가 있는 애니메이션 장면이 들어 있습니다. 각 타임라인 마커는 `base-00`, `hairHeart-04`처럼 앱의 동작과 프레임을 나타냅니다.

- `catalog.py`: 기존 20개 PNG 시트와 실제 불균등 자르기 영역.
- `pose-catalog.json`: Blender 프레임 번호와 동작의 대응표.
- `build_animation.py`: 원본 피규어 장면에서 포즈와 소품을 구성하는 생성 스크립트.
- `add_inbetweens.py`: 전환 경로의 13개 중간 자세를 모델의 위치·회전·곡선 제어점으로 보간해 추가합니다.
- `render_sprites.py`: 저장된 애니메이션의 257개 투명 PNG 재렌더링.
- `package_sprites.py`: 공통 배율과 바닥 기준을 적용해 앱용 프레임과 호환 시트 생성.
- `validate_sprites.py`: 원본 시트 전체 포함 여부, 프레임 수, 크기, 알파와 잘림 검사.
- `../rendered-3d/frames/`: 양쪽 앱에서 사용하는 627×627 RGBA 프레임.
- `../rendered-3d/atlases/`: 기존 20개 시트와 이름·크기·자르기 영역이 같은 3D 버전.
- `../rendered-3d/manifest.json`: 앱에서 검사하는 버전·프레임 목록. `landed`는 `liftPose-03`의 별칭이므로 파일 수는 257, Mac 논리 프레임 수는 258입니다.

## 재렌더링

저장소 루트에서 (macOS의 Blender 설치 경로 예시):

```sh
/Applications/Blender.app/Contents/MacOS/Blender assets/3d/kikki-animation.blend --background --python assets/3d/render_sprites.py
uv run --with pillow python assets/3d/package_sprites.py
uv run --with pillow python assets/3d/validate_sprites.py
bash macos/build.sh --native
```

Blender MCP에서도 `execute_blender_code`로 `render_sprites.py`를 실행할 수 있습니다. 스크립트를 `exec`로 실행할 때 `__file__`에 해당 스크립트의 절대 경로를 전달합니다. 일괄 렌더링 시 UI가 잠시 바쁠 수 있으므로 짧은 배치나 Blender 타이머로 나누어 실행할 수 있습니다.

`build_animation.py`는 원본 피규어 장면을 유지하며 새 애니메이션 장면을 생성합니다. 재생성 전 현재 작업을 별도 저장하고, 새 장면과 기존 장면을 확인한 뒤 배포할 장면을 선택하세요. `create_kikki.py`와 `refine_kikki_limbs.py`는 최초 피규어 제작 기록이며 당시 로컬 출력 경로를 포함합니다.

## 동작과 플랫폼

2D/3D 전환은 렌더러를 바꾸지 않고 표시 이미지 뱅크만 교체합니다. 양쪽 모드의 시트 키와 프레임 순서가 같으므로 진행 중인 동작을 이어갈 수 있습니다. 3D 뱅크는 최초 전환 때 전부 검사한 뒤 교체하고 재사용합니다.

Mac은 `UserDefaults.visualStyle`, Windows는 `%LOCALAPPDATA%\Kikki\visual-style.txt`에 선택을 보관합니다. Windows의 크로스페이드와 떨어지는 폰도 같이 교체됩니다. 저장된 선택이 3D인데 파일이 없거나 손상됐다면 2D로 시작합니다.

검증: Mac의 Apple Silicon 실행·전체 자체 검사·Universal 두 아키텍처 빌드와 이미지 검사를 수행했습니다. Windows 연결 코드와 구문은 검사했으며, WPF 런타임 검사는 Windows에서 `powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -File .\Doongi.ps1 -SelfTest`로 수행해야 합니다. 이 명령에 `VisualStyle.Tests.ps1`도 포함됩니다.


## 자연스러운 팔과 빠른 자세 전환

팔은 몸 안쪽에서 시작해 상완·팔꿈치·손목을 지나는 네 제어점과 가변 굵기로 만듭니다. 손 방향은 전완의 방향을 따르며, 바나나를 들 때는 팔꿈치를 아래로 굽히고 쉬는 손은 무릎 쪽으로 둡니다.

2D는 원래 0.22초 자세 간격을 유지합니다. 3D는 원래 자세 간격을 0.14초로 줄이고 절반 시점에 실제 모델 중간 자세를 보여주므로 화면 갱신은 0.07초마다 일어납니다. 연속 인덱스 외에 4↔7, 4↔6 경로도 포함합니다. 자동 활동 선택 간격은 바꾸지 않습니다. 전환 도중 2D/3D를 바꾸면 경과 비율을 유지하도록 시작 시간을 환산합니다.

모델을 다시 생성할 때는 `build_animation.py` 이후 `add_inbetweens.py`, `add_action_frames.py`를 순서대로 실행한 뒤 렌더링·패키징합니다. 저장된 `.blend`와 카탈로그에는 이미 중간 자세가 들어 있습니다.

3D 걷기는 32프레임(고개 돌린 걷기도 32), 폰 보기는 24프레임 순환, 하트 만들기는 21프레임, 폰 줍기는 13프레임입니다. 기존 이동 거리·시간과 자동 활동 간격을 유지합니다.
