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

# 0.5) Pre-check — git must be installed (uv shells out to system git for the
#      fork dependency below; uv cannot install git itself)
if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Write-Host ""
    Write-Host "[WARN] Git is not installed."
    Write-Host "  -> Install it from https://git-scm.com/download/win, then re-run this script."
    exit 1
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

# 2) Download pyproject.toml if missing (this folder is reused as-is for the whole
#    course, so if the file already exists here, it was created by a previous run)
if (-not (Test-Path "pyproject.toml")) {
    try {
        irm https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/pyproject.toml -OutFile pyproject.toml
    } catch {
        Write-Host ""
        Write-Host "[WARN] pyproject.toml download failed. Check network access and try again."
        exit 1
    }
}

# 3) Install dependencies (requires-python == 3.11.* pins the venv to 3.11
#    regardless of whatever Python is already on the student's PC)
uv sync
if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "[WARN] Dependency install failed (uv sync)."
    Write-Host "  -> Check network access to the fork branch and try again."
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
#    m4_data\datasets already exists at this point (created automatically
#    during step 4), so no separate mkdir is needed. This only registers
#    the "cvd" dataset with m4 — converting the student-provided
#    cvd.csv.gz into DuckDB (uv run m4 init cvd --src ...) is done later
#    in class, not by this script.
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
