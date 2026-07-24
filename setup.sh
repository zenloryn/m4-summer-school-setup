#!/bin/bash
# setup.sh
set -e

# 1) uv 설치 (이미 있으면 스킵)
if ! command -v uv &> /dev/null; then
    echo "uv 설치 중..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

# 2) pyproject.toml 다운로드 (이미 있으면 스킵 — 폴더 하나만 재사용하는 운영 방식이라
#    이 시점에 파일이 있다면 그건 100% 이전 실행으로 생긴 것)
if [ ! -f "pyproject.toml" ]; then
    curl -fsSL https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/pyproject.toml -o pyproject.toml
fi

# 3) 설치
if ! uv sync; then
    echo "⚠️  의존성 설치 실패 (uv sync). fork 브랜치 접근이나 네트워크 상태를 확인하고 스크립트를 다시 실행하세요."
    exit 1
fi

# 4) MIMIC-IV demo 데이터 초기화
if ! uv run m4 init mimic-iv-demo; then
    echo "⚠️  MIMIC-IV demo 데이터 초기화 실패. 네트워크 연결을 확인하고 스크립트를 다시 실행하세요."
    exit 1
fi

# 5) Claude Desktop 연동
if uv run m4 config claude --skills; then
    echo "✅ 완료. Claude Desktop을 완전히 종료했다가 재시작하세요."
else
    echo "⚠️  Claude Desktop 설정 파일을 찾지 못했습니다."
    echo "   -> Claude Desktop을 설치하고 한 번 실행한 뒤, 이 스크립트를 다시 실행하세요."
    echo "   -> 다운로드: https://claude.ai/download"
fi
