#!/usr/bin/env bash
# install-end4.sh — apply ONLY the end4 (Hyprland ii) files to the live system.
# Run this when setting up the Hyprland arm of the user's setup.
# Use ../install.sh for the Niri arm.

set -euo pipefail
REPO="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"

# Defer to the original restore.sh for the actual patching — it's already
# vetted and matches the end4 README.
bash "${REPO}/restore.sh"
