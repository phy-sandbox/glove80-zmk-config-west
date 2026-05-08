#!/usr/bin/env bash
# setup-zmk-env.sh - One-shot script to set up a pristine ZMK/Zephyr build environment in WSL/Ubuntu
# Usage: bash setup-zmk-env.sh [TARGET_DIR]
# If TARGET_DIR is not provided, uses ~/zmk-workspace
set -euo pipefail

# --- Configurable variables ---
TARGET_DIR="${1:-$HOME/glove80_dongle/glove80-zmk-config-west}"
ZMK_REPO="https://github.com/phy-sandbox/zmk.git"
ZMK_LOCAL="$HOME/glove80_dongle/zmk"
ZMK_TAG="glove80_dongle"
ZEPHYR_SDK_VERSION="0.16.8"
ZEPHYR_SDK_URL="https://github.com/zephyrproject-rtos/sdk-ng/releases/download/v${ZEPHYR_SDK_VERSION}/zephyr-sdk-${ZEPHYR_SDK_VERSION}_linux-x86_64.tar.xz"

mkdir -p "$TARGET_DIR"
cd "$TARGET_DIR"

# --- System prerequisites ---
echo "[1/6] Installing system packages..."
sudo apt-get update
sudo apt-get install -y git cmake ninja-build gperf python3-pip python3-setuptools python3-wheel python3-venv xz-utils file make gcc gcc-multilib g++-multilib libsdl2-dev libmagic1 wget rsync

# --- Python tools ---
echo "[2/6] Installing west (Zephyr meta-tool)..."
pip3 install --user -U pipx --break-system-packages
export PATH="$HOME/.local/bin:$PATH"

# Ensure pipx path is permanently available
pipx ensurepath
pipx install --force west

# Verify west installation
WEST_BIN="$(command -v west)"
if [ ! -x "$WEST_BIN" ]; then
    echo "ERROR: west not found at $WEST_BIN after installation"
    exit 1
fi

# --- Zephyr SDK ---
echo "[3/6] Installing Zephyr SDK v${ZEPHYR_SDK_VERSION}..."
cd "$HOME"
if [ ! -d "zephyr-sdk-${ZEPHYR_SDK_VERSION}" ]; then
    wget "$ZEPHYR_SDK_URL" -O zephyr-sdk.tar.xz
    tar xf zephyr-sdk.tar.xz
    rm zephyr-sdk.tar.xz
    cd "zephyr-sdk-${ZEPHYR_SDK_VERSION}"
    # Run setup.sh non-interactively; disable pipefail to tolerate SIGPIPE from `yes`
    (
        set +o pipefail
        yes | bash ./setup.sh
    )
    cd "$HOME"
else
    echo "Zephyr SDK already present. Skipping download."
fi
export ZEPHYR_SDK_INSTALL_DIR="$HOME/zephyr-sdk-${ZEPHYR_SDK_VERSION}"
if ! grep -q ZEPHYR_SDK_INSTALL_DIR "$HOME/.bashrc"; then
    echo "export ZEPHYR_SDK_INSTALL_DIR=\"$HOME/zephyr-sdk-${ZEPHYR_SDK_VERSION}\"" >> "$HOME/.bashrc"
fi

# --- ZMK source and west workspace ---
echo "[4/6] Setting up working ZMK repository..."
if [ ! -d "$ZMK_LOCAL" ]; then
    # Clone requires network access (one-time)
    git clone "$ZMK_REPO" "$ZMK_LOCAL"
    git -C "$ZMK_LOCAL" checkout "$ZMK_TAG"
else
    echo "Working ZMK repository already present."
fi

# --- Initialize west workspace ---
echo "[5/6] Initialise west workspace from config repo..."
cd "$TARGET_DIR"
if [ ! -d .west ]; then
    [ -d config ] || { echo "ERROR: config/ repo not found"; exit 1; }
    "$WEST_BIN" init -l config
fi
# Initial setup: do a full fetch for reliability
"$WEST_BIN" config project.zmk.url "$(realpath "$ZMK_LOCAL")"
"$WEST_BIN" update -f always

# Ensure pyelftools is installed in the venv for Zephyr build scripts
pipx inject west pyelftools

# --- Final instructions ---
echo "[6/6] Environment setup complete!"
