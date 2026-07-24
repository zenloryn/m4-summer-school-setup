# setup.ps1
$ErrorActionPreference = "Stop"

# 1) uv 설치 (이미 있으면 스킵)
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv 설치 중..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
uv --version

# 2) pyproject.toml 다운로드 (이미 있으면 스킵 — 폴더 하나만 재사용하는 운영 방식이라
#    이 시점에 파일이 있다면 그건 100% 이전 실행으로 생긴 것)
if (-not (Test-Path "pyproject.toml")) {
    irm https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/pyproject.toml -OutFile pyproject.toml
}

# 3) 설치 (requires-python == 3.11.* 고정 덕분에 학생 PC의 기존 파이썬 버전과 무관하게
#    .venv 안에는 항상 3.11이 격리되어 설치됨. venv 활성화 불필요 — uv run으로 대체)
uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n⚠️  의존성 설치 실패 (uv sync). fork 브랜치 접근이나 네트워크 상태를 확인하고 스크립트를 다시 실행하세요."
    exit 1
}

# 4) MIMIC-IV demo 데이터 초기화
uv run m4 init mimic-iv-demo
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n⚠️  MIMIC-IV demo 데이터 초기화 실패. 네트워크 연결을 확인하고 스크립트를 다시 실행하세요."
    exit 1
}

# 5) Claude Desktop 연동 (MSIX 자동탐지 패치 반영)
uv run m4 config claude --skills
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ 완료. Claude Desktop을 완전히 종료했다가 재시작하세요."
} else {
    Write-Host "`n⚠️  Claude Desktop 설정 파일을 찾지 못했습니다."
    Write-Host "   -> Claude Desktop을 설치하고 한 번 실행한 뒤, 이 스크립트를 다시 실행하세요."
    Write-Host "   -> 다운로드: https://claude.ai/download"
}
