#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
if ! xcrun --find swiftc >/dev/null 2>&1; then
    echo "Mac 개발 도구가 필요합니다. 터미널에서 xcode-select --install을 실행한 뒤 다시 열어주세요."
    read -r -p "Enter를 누르면 닫습니다. "
    exit 1
fi
# Reopen the new binary instead of handing the launch back to an old running build.
pkill -x Kikki >/dev/null 2>&1 || true
if ! /bin/bash "$ROOT/macos/build.sh" --native; then
    echo "빌드에 실패했습니다. 위 오류를 확인해주세요."
    read -r -p "Enter를 누르면 닫습니다. "
    exit 1
fi
open "$ROOT/outputs/macos-dev/Kikki.app"
