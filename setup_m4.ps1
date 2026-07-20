# setup_m4.ps1
$ErrorActionPreference = "Stop"

# 1) uv 설치 (이미 있으면 스킵)
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "uv 설치 중..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
uv --version

# 2) uv 프로젝트 초기화 (이미 됐으면 스킵)
if (-not (Test-Path "pyproject.toml")) {
    uv init
}

# 3) m4-infra를 dependencies에 등록 (기존 "dependencies = []"를 교체, 무조건 추가하지 않음)
$pyproject = Get-Content pyproject.toml -Raw
if ($pyproject -notmatch "m4-infra") {
    if ($pyproject -match "dependencies\s*=\s*\[\]") {
        $pyproject = $pyproject -replace "dependencies\s*=\s*\[\]", 'dependencies = ["m4-infra"]'
    } else {
        $pyproject += "`ndependencies = [`"m4-infra`"]`n"
    }
    Set-Content pyproject.toml $pyproject -NoNewline
    $pyproject = Get-Content pyproject.toml -Raw
}

# 4) 패치된 fork를 소스로 지정 (PyPI 정식 릴리스 나오기 전까지 임시 우회)
$sourceBlock = @"

[tool.uv.sources]
m4-infra = { git = "https://github.com/zenloryn/m4.git", branch = "fix/windows-msix-claude-config" }
"@
if ($pyproject -notmatch "\[tool\.uv\.sources\]") {
    Add-Content pyproject.toml $sourceBlock
}

# 5) 설치 (venv 활성화 불필요)
uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n⚠️  의존성 설치 실패 (uv sync). fork 브랜치 접근이나 네트워크 상태를 확인하고 스크립트를 다시 실행하세요."
    exit 1
}

# 6) MIMIC-IV demo 데이터 초기화
uv run m4 init mimic-iv-demo
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n⚠️  MIMIC-IV demo 데이터 초기화 실패. 네트워크 연결을 확인하고 스크립트를 다시 실행하세요."
    exit 1
}

# 7) Claude Desktop 연동 (MSIX 자동탐지 패치 반영)
uv run m4 config claude --skills
if ($LASTEXITCODE -eq 0) {
    Write-Host "`n✅ 완료. Claude Desktop을 완전히 종료했다가 재시작하세요."
} else {
    Write-Host "`n⚠️  Claude Desktop 설정 파일을 찾지 못했습니다."
    Write-Host "   -> Claude Desktop을 설치하고 한 번 실행한 뒤, 이 스크립트를 다시 실행하세요."
    Write-Host "   -> 다운로드: https://claude.ai/download"
}