#!/usr/bin/env bash
# build-local.sh - Local build script for Glove80 Dongle-Central firmware
# Usage: ./build-local.sh [REPO_DIR]
# If REPO_DIR is not provided, uses current directory.
# Script must be run inside WSL (Linux).
# Can be invoked from Windows via: wsl -e bash path/to/build-local.sh

set -euo pipefail

# Parse arguments:build directory
REPO_DIR=""
for arg in "$@"; do
    if [ -z "$REPO_DIR" ]; then
        REPO_DIR="$arg"
    fi
done

# Default to current directory if no build dir given
if [ -z "$REPO_DIR" ]; then
    REPO_DIR="."
fi
REPO_DIR="$(cd "$REPO_DIR" && pwd)"
SCRIPT_DIR="$REPO_DIR/scripts"
ZMK_WORKING_COPY="$HOME/glove80_dongle/zmk"
ZMK_TAG="glove80_dongle"
WINUSER=$(powershell.exe '$env:USERNAME' | tr -d '\r\n')
DONGLE_BOARD="${DONGLE_BOARD:-nrf52840_mdk_usb_dongle}"

export PATH="$HOME/.local/bin:$PATH"

# Validate we're in a repo with the expected structure
if [ ! -d "$REPO_DIR/zmk" ] || [ ! -d "$REPO_DIR/config" ] || [ ! -f "$REPO_DIR/config/west.yml" ]; then
    echo "ERROR: $REPO_DIR does not appear to be a valid glove80-dongle repository"
    echo "Usage: $0 [REPO_DIR]"
    exit 1
fi

cd "$REPO_DIR"

# Always log build output to build/build-output.log and stdout.
mkdir -p build
LOG_FILE="$REPO_DIR/build/build-output.log"
exec > >(tee "$LOG_FILE") 2>&1
echo "[log] Writing build log to: $LOG_FILE"

# Find west executable
WEST_BIN="$(command -v west)"
if [ ! -x "$WEST_BIN" ]; then
    echo "ERROR: west not found at $WEST_BIN"
    echo "Please install west via: pipx install west"
    exit 1
fi

echo "======================================================================"
echo "Glove80 Dongle-Central Local Build"
echo "======================================================================"
echo "Repository: $REPO_DIR"
echo "West binary: $WEST_BIN"
echo "Dongle board: $DONGLE_BOARD"
echo ""

# ============================================================================
# NETWORK DETECTION
# ============================================================================

# Default: assume offline unless proven otherwise
HAVE_NETWORK=0

check_network() {
    # Fast, low-impact checks in increasing cost order

    # 1. DNS resolution (fast, no external traffic)
    if ! getent hosts github.com >/dev/null 2>&1; then
        return 1
    fi

    # 2. HTTPS HEAD request with short timeout
    if command -v curl >/dev/null 2>&1; then
        curl -fsI --connect-timeout 2 --max-time 4 https://github.com >/dev/null 2>&1 || return 1
    else
        # fallback to ping if curl is unavailable
        ping -c 1 -W 2 github.com >/dev/null 2>&1 || return 1
    fi

    return 0
}

if check_network; then
    HAVE_NETWORK=1
    echo "[net] Network connectivity detected"
else
    echo "[net] No network connectivity detected (offline mode)"
fi

run_if_online() {
    local description="$1"
    shift

    if [ "$HAVE_NETWORK" -eq 1 ]; then
        echo "[net] Running: $description"
        "$@"
    else
        echo "[net] Skipping: $description (offline)"
    fi
}

# Step 1: Clean old builds (preserve artifacts)
echo "[1/12] Cleaning old build artifacts..."
find build -mindepth 1 -maxdepth 1 -type d ! -name combined -exec rm -rf {} + 2>/dev/null || true

# Step 2: Update pristine ZMK mirror (transport cache)
echo "[2/12] Checking working ZMK repository..."
if [ ! -d "$ZMK_WORKING_COPY" ]; then
    echo "ERROR: working ZMK repository not found at $ZMK_WORKING_COPY"
    exit 1
fi

# Step 3: Reset west workspace to manifest state (offline-capable)
echo "[3/12] Reset west workspace to manifest state (offline-capable)..."
run_if_online "west update" \
    "$WEST_BIN" update -f always

# west zephyr-export is required so find_package(Zephyr) works in non-interactive scripts
"$WEST_BIN" zephyr-export || true

# Step 4-6: Build main firmware targets
echo "[4/11] Building dongle (glove80_dongle shield)..."
"$WEST_BIN" build -s zmk/app -b "$DONGLE_BOARD" -d build/dongle --pristine=always -- -DSHIELD=glove80_dongle -DZMK_CONFIG="$REPO_DIR/config" || exit 1

echo "[5/11] Building left half (glove80_lh)..."
"$WEST_BIN" build -s zmk/app -b glove80_lh -d build/left --pristine=always -- -DZMK_CONFIG="$REPO_DIR/config" || exit 1

echo "[6/11] Building right half (glove80_rh)..."
"$WEST_BIN" build -s zmk/app -b glove80_rh -d build/right --pristine=always -- -DZMK_CONFIG="$REPO_DIR/config" || exit 1

# Step 7-9: Build settings-reset firmware targets
echo "[7/11] Building settings_reset (dongle, clears bonds)..."
"$WEST_BIN" build -s zmk/app -b "$DONGLE_BOARD" -d build/settings-reset-dongle --pristine=always -- \
  -DSHIELD=settings_reset -DZMK_CONFIG="$REPO_DIR/config" \
  -DEXTRA_CONF_FILE="$REPO_DIR/config/settings_reset.conf;$REPO_DIR/config/reset_bonds.conf" || exit 1

echo "[8/11] Building settings_reset (left half)..."
"$WEST_BIN" build -s zmk/app -b glove80_lh -d build/settings-reset-lh --pristine=always -- \
  -DSHIELD=settings_reset -DZMK_CONFIG="$REPO_DIR/config" \
  -DEXTRA_CONF_FILE="$REPO_DIR/config/settings_reset.conf" || exit 1

echo "[9/11] Building settings_reset (right half)..."
"$WEST_BIN" build -s zmk/app -b glove80_rh -d build/settings-reset-rh --pristine=always -- \
  -DSHIELD=settings_reset -DZMK_CONFIG="$REPO_DIR/config" \
  -DEXTRA_CONF_FILE="$REPO_DIR/config/settings_reset.conf" || exit 1

echo "[10/11] Collecting UF2 artifacts..."
mkdir -p build/combined

copy_uf2() {
    local src_dir="$1"
    local out_name="$2"
    local src_file

    if [ -f "$src_dir/zephyr/zmk.uf2" ]; then
        src_file="$src_dir/zephyr/zmk.uf2"
    else
        src_file="$(find "$src_dir/zephyr" -maxdepth 1 -name '*.uf2' -print -quit)"
    fi

    if [ -z "${src_file:-}" ] || [ ! -f "$src_file" ]; then
        echo "ERROR: UF2 not found in $src_dir/zephyr"
        exit 1
    fi

    cp "$src_file" "build/combined/$out_name"
}

copy_uf2 "build/dongle" "glove80_dongle-${DONGLE_BOARD}-zmk.uf2"
copy_uf2 "build/left" "glove80_lh-zmk.uf2"
copy_uf2 "build/right" "glove80_rh-zmk.uf2"
copy_uf2 "build/settings-reset-dongle" "settings-reset-dongle-zmk.uf2"
copy_uf2 "build/settings-reset-lh" "settings-reset-glove80_lh-zmk.uf2"
copy_uf2 "build/settings-reset-rh" "settings-reset-glove80_rh-zmk.uf2"

echo "[11/11] Build complete. UF2 files are in build/combined/ and /mnt/c/Users/$WINUSER/Documents/transfer/:"
ls -1 build/combined/*.uf2

cp -v $HOME/glove80_dongle/glove80-zmk-config-west/build/combined/*.uf2 \
  "/mnt/c/Users/$WINUSER/Documents/transfer/"

ls -lh /mnt/c/Users/$WINUSER/Documents/transfer/*.uf2
