# setup.ps1
$ErrorActionPreference = "Stop"

# 0) Pre-checks — path length and free disk space
$currentPath = (Get-Location).Path
if ($currentPath.Length -gt 100) {
    Write-Host "[WARN] Current folder path is long ($($currentPath.Length) chars). If you hit a 'path too long' error later, move to a shorter path like C:\m4-research and retry."
}
try {
    $freeGB = (Get-PSDrive -Name ($currentPath.Substring(0,1))).Free / 1GB
    if ($freeGB -lt 2) {
        Write-Host "[WARN] Less than 2GB free disk space. Free up space before continuing."
    }
} catch {
    Write-Host "[WARN] Could not check free disk space. Continuing anyway."
}

# 0.5) Pre-check — git should be installed (uv shells out to system git for the
#      fork dependency below). Warn only, don't block: if this check has a
#      false negative, step 3 (uv add) will still catch a real problem with
#      its own specific message below.
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host "[WARN] Git does not appear to be installed. If step 3 below fails, install it from https://git-scm.com/download/win and re-run this script."
}

# 1) Install uv if missing
if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
    Write-Host "Installing uv..."
    powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
    $env:Path = "$env:USERPROFILE\.local\bin;$env:Path"
    if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
        Write-Host ""
        Write-Host "[WARN] uv installation failed. Check network access and try again, or install manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    }
}
uv --version

# 2) Initialize uv project pinned to Python 3.11+ (skip if already initialized;
#    this folder is reused as-is for the whole course)
if (-not (Test-Path "pyproject.toml")) {
    uv init --python 3.11
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "[WARN] Project initialization failed (uv init). This may need to download Python 3.11 - check network access and try again."
        exit 1
    }
}

# 3) Install m4-infra from the course fork (uv add safely merges this into
#    pyproject.toml/uv.lock — safe to re-run)
uv add "m4-infra @ git+https://github.com/zenloryn/m4.git"
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARN] Dependency install failed (uv add)."
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
        Write-Host "  -> Git is not installed. Install it from https://git-scm.com/download/win, then re-run this script."
    } else {
        Write-Host "  -> Check network access to the fork repository and try again."
    }
    exit 1
}

# 4) Initialize MIMIC-IV demo dataset
Write-Host "Downloading MIMIC-IV demo data - this can take a few minutes, this is normal."
uv run m4 init mimic-iv-demo
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARN] MIMIC-IV demo data initialization failed. Check your network connection and try again."
    exit 1
}

# 5) Connect to Claude Desktop (includes the Windows MSIX path-detection patch)
#    Moved ahead of the cvd.json step: this is the step students actually need
#    for class, so a flaky download below should never block it.
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

# 6) Download cvd custom dataset definition (skip if already present).
#    Non-fatal on failure: Claude Desktop is already configured above, so a
#    flaky network at this last step shouldn't block the rest of setup.
$cvdJsonPath = "m4_data\datasets\cvd.json"
if (-not (Test-Path $cvdJsonPath)) {
    New-Item -ItemType Directory -Path (Split-Path $cvdJsonPath) -Force | Out-Null
    try {
        irm https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/cvd.json -OutFile $cvdJsonPath
    } catch {
        Write-Host ""
        Write-Host "[WARN] cvd.json download failed. Check network access and try again."
        Write-Host "  -> This only affects the 'cvd' dataset used later in class; Claude Desktop setup above is unaffected."
    }
}
