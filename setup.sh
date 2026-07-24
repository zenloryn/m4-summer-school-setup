#!/bin/bash
# setup.sh
set -e

# 0) Pre-check — free disk space (in KB, macOS/Linux df output)
FREE_KB=$(df -k . | tail -1 | awk '{print $4}')
FREE_GB=$((FREE_KB / 1024 / 1024))
if [ "$FREE_GB" -lt 2 ]; then
    echo "[WARN] Less than 2GB free disk space. Free up space before continuing."
fi

# 1) Install uv if missing
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
fi
uv --version

# 2) Download pyproject.toml if missing (this folder is reused as-is for the whole
#    course, so if the file already exists here, it was created by a previous run)
if [ ! -f "pyproject.toml" ]; then
    curl -fsSL https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/pyproject.toml -o pyproject.toml
fi

# 3) Install dependencies (requires-python == 3.11.* pins the venv to 3.11
#    regardless of whatever Python is already on the student's machine)
if ! uv sync; then
    echo "[WARN] Dependency install failed (uv sync)."
    if ! xcode-select -p &> /dev/null; then
        echo "  -> Xcode Command Line Tools not found. Run: xcode-select --install"
        echo "     Then wait for the install to finish and re-run this script."
    elif ! command -v openssl &> /dev/null; then
        echo "  -> openssl not found. Run: brew install openssl pkgconf"
        echo "     (if brew is missing, install it first from https://brew.sh)"
    else
        echo "  -> Check network access to the fork branch and try again."
    fi
    exit 1
fi

# 4) Initialize MIMIC-IV demo dataset
echo "Downloading MIMIC-IV demo data - this can take a few minutes, this is normal."
if ! uv run m4 init mimic-iv-demo; then
    echo "[WARN] MIMIC-IV demo data initialization failed. Check your network connection and try again."
    exit 1
fi

# 5) Connect to Claude Desktop
if uv run m4 config claude --skills; then
    echo "[OK] Setup complete. Fully quit and restart Claude Desktop."
else
    echo "[WARN] Could not find the Claude Desktop config file."
    echo "  -> Install Claude Desktop, open it at least once, then run this script again."
    echo "  -> Download: https://claude.ai/download"
fi
