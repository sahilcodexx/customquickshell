#!/usr/bin/env bash
# install-all.sh — apply both niri/ and end4/ to the live system.
# Useful for fresh installs where you want everything.

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

bash "${SCRIPT_DIR}/install.sh"
echo ""
echo "=== Now applying end4 files (Hyprland ii) ==="
echo "Skipping end4 by default — only run on Hyprland setups."
echo "Run 'bash ${SCRIPT_DIR}/end4/install-end4.sh' to apply end4."
