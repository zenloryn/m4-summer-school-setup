#!/bin/bash
# setup.sh
set -e

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
    echo "[WARN] Dependency install failed (uv sync). Check network access to the fork branch and try again."
    exit 1
fi

# 4) Initialize MIMIC-IV demo dataset
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
