#!/bin/bash
# setup.sh
set -e
set -o pipefail

# 0) Pre-check — free disk space (in KB, macOS/Linux df output)
if FREE_KB=$(df -k . 2>/dev/null | tail -1 | awk '{print $4}') && [ -n "$FREE_KB" ]; then
    FREE_GB=$((FREE_KB / 1024 / 1024))
    if [ "$FREE_GB" -lt 2 ]; then
        echo "[WARN] Less than 2GB free disk space. Free up space before continuing."
    fi
else
    echo "[WARN] Could not check free disk space. Continuing anyway."
fi

# 0.5) Pre-check — git should be installed (uv shells out to system git for the
#      fork dependency below). Warn only, don't block: if this check has a
#      false negative, step 3 (uv add) will still catch a real problem with
#      its own specific message below.
if ! command -v git &> /dev/null; then
    if [ "$(uname)" = "Darwin" ]; then
        echo "[WARN] Git does not appear to be installed. If step 3 below fails, run 'xcode-select --install' and re-run this script."
    else
        echo "[WARN] Git does not appear to be installed. If step 3 below fails, install git for your distribution (e.g. sudo apt install git) and re-run this script."
    fi
fi

# 1) Install uv if missing
if ! command -v uv &> /dev/null; then
    echo "Installing uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh
    export PATH="$HOME/.local/bin:$PATH"
    if ! command -v uv &> /dev/null; then
        echo ""
        echo "[WARN] uv installation failed. Check network access and try again, or install manually: https://docs.astral.sh/uv/getting-started/installation/"
        exit 1
    fi
fi
uv --version

# 2) Initialize uv project pinned to Python 3.11+ (skip if already initialized;
#    this folder is reused as-is for the whole course)
if [ ! -f "pyproject.toml" ]; then
    if ! uv init --python 3.11; then
        echo "[WARN] Project initialization failed (uv init). This may need to download Python 3.11 - check network access and try again."
        exit 1
    fi
fi

# 3) Install m4-infra from the course fork (uv add safely merges this into
#    pyproject.toml/uv.lock — safe to re-run)
if ! uv add "m4-infra @ git+https://github.com/zenloryn/m4.git"; then
    echo "[WARN] Dependency install failed (uv add)."
    if ! command -v git &> /dev/null; then
        if [ "$(uname)" = "Darwin" ]; then
            echo "  -> Git is not installed. Run: xcode-select --install"
            echo "     A popup will appear — click Install, wait for it to finish, then re-run this script."
        else
            echo "  -> Git is not installed. Install git for your distribution (e.g. sudo apt install git), then re-run this script."
        fi
    elif [ "$(uname)" = "Darwin" ]; then
        if ! xcode-select -p &> /dev/null; then
            echo "  -> Xcode Command Line Tools not found. Run: xcode-select --install"
            echo "     Then wait for the install to finish and re-run this script."
        elif ! command -v openssl &> /dev/null; then
            echo "  -> openssl not found. Run: brew install openssl pkgconf"
            echo "     (if brew is missing, install it first from https://brew.sh)"
        else
            echo "  -> Check network access to the fork repository and try again."
        fi
    else
        echo "  -> Check network access to the fork repository and try again."
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
#    Moved ahead of the cvd.json step: this is the step students actually need
#    for class, so a flaky download below should never block it.
if uv run m4 config claude --skills; then
    echo "[OK] Setup complete. Fully quit and restart Claude Desktop."
else
    echo "[WARN] Could not find the Claude Desktop config file."
    echo "  -> Install Claude Desktop, open it at least once, then run this script again."
    echo "  -> Download: https://claude.ai/download"
fi

# 6) Download cvd custom dataset definition (skip if already present).
#    Non-fatal on failure: Claude Desktop is already configured above, so a
#    flaky network at this last step shouldn't block the rest of setup.
CVD_JSON_PATH="m4_data/datasets/cvd.json"
if [ ! -f "$CVD_JSON_PATH" ]; then
    mkdir -p "$(dirname "$CVD_JSON_PATH")"
    if ! curl -fsSL https://raw.githubusercontent.com/zenloryn/m4-summer-school-setup/main/cvd.json -o "$CVD_JSON_PATH"; then
        echo "[WARN] cvd.json download failed. Check network access and try again."
        echo "  -> This only affects the 'cvd' dataset used later in class; Claude Desktop setup above is unaffected."
    fi
fi
