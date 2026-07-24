# setup.ps1
$ErrorActionPreference = "Stop"

# 1) Install uv if missing
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
}
uv --version

# 2) Download pyproject.toml if missing (this folder is reused as-is for the whole
#    course, so if the file already exists here, it was created by a previous run)
if (-not (Test-Path "pyproject.toml")) {
    irm https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/pyproject.toml -OutFile pyproject.toml
}

# 3) Install dependencies (requires-python == 3.11.* pins the venv to 3.11
#    regardless of whatever Python is already on the student's PC)
uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARN] Dependency install failed (uv sync). Check network access to the fork branch and try again."
    exit 1
}

# 4) Initialize MIMIC-IV demo dataset
uv run m4 init mimic-iv-demo
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARN] MIMIC-IV demo data initialization failed. Check your network connection and try again."
    exit 1
}

# 5) Connect to Claude Desktop (includes the Windows MSIX path-detection patch)
uv run m4 config claude --skills
if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "[OK] Setup complete. Fully quit and restart Claude Desktop."
} else {
    Write-Host ""
    Write-Host "[WARN] Could not find the Claude Desktop config file."
    Write-Host "  -> Install Claude Desktop, open it at least once, then run this script again."
    Write-Host "  -> Download: https://claude.ai/download"
}
