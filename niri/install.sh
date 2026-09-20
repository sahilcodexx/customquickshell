#!/usr/bin/env bash
# install.sh — re-apply every file in this folder to its real location.
#
# Idempotent: safe to re-run. Existing files are overwritten in place.
# Run from anywhere; paths are resolved relative to this script.
#
# Only applies files from ./niri/ — leaves ./end4/ alone (end4 files are
# restored separately via end4/restore.sh when running Hyprland).

set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"

echo "==[1/5]== Installing niri config"
mkdir -p "${HOME_DIR}/.config/niri"
cp -v "${REPO}/niri/niri/config.kdl" "${HOME_DIR}/.config/niri/config.kdl"

echo "==[1b/5]== Installing GTK corner-radius settings"
mkdir -p "${HOME_DIR}/.config/gtk-3.0" "${HOME_DIR}/.config/gtk-4.0"
cp -v "${REPO}/niri/noctalia/dotfiles/gtk/gtk-3.0-settings.ini" "${HOME_DIR}/.config/gtk-3.0/settings.ini"
cp -v "${REPO}/niri/noctalia/dotfiles/gtk/gtk-4.0-settings.ini" "${HOME_DIR}/.config/gtk-4.0/settings.ini"

echo "==[2/5]== Installing xdg-desktop-portal config"
mkdir -p "${HOME_DIR}/.config/xdg-desktop-portal"
cp -v "${REPO}/niri/noctalia/dotfiles/xdg-desktop-portal.conf" \
       "${HOME_DIR}/.config/xdg-desktop-portal/hyprland-portals.conf"
systemctl --user restart xdg-desktop-portal.service 2>/dev/null || true

echo "==[3/5]== Installing nightlight-set helper"
mkdir -p "${HOME_DIR}/.local/bin"
cp -v "${REPO}/niri/bin/nightlight-set" "${HOME_DIR}/.local/bin/nightlight-set"
chmod +x "${HOME_DIR}/.local/bin/nightlight-set"

echo "==[4/5]== Installing nightlight-slider plugin"
SRC="${HOME_DIR}/.local/state/noctalia/plugins/sources/local/repo/nightlight-slider"
mkdir -p "$(dirname "${SRC}")"
rm -rf "${SRC}"
cp -r "${REPO}/niri/noctalia/plugins/nightlight-slider" "${SRC}"
# First-time git init if the source dir isn't a repo yet.
if [[ ! -d "${SRC}/.git" ]]; then
  ( cd "$(dirname "${SRC}")" && git init -q && \
    git -c user.email=local@local -c user.name=local add nightlight-slider && \
    git -c user.email=local@local -c user.name=local commit -q -m "nightlight-slider initial" )
fi

# Register the local source and enable the plugin if not already.
if ! noctalia msg plugins source list 2>/dev/null | grep -q "local "; then
  noctalia msg plugins source add local path "$(dirname "${SRC}")" || true
fi
if ! noctalia msg plugins list 2>/dev/null | grep -q "local/nightlight-slider"; then
  noctalia msg plugins enable local/nightlight-slider || true
fi

echo "==[5/5]== Done"
echo "Open the night light slider panel: Mod+Shift+N"
echo "See mycustomsetup.md for full docs."

echo ""
echo "Note: ./end4/ contents are NOT installed by this script."
echo "Use end4/restore.sh instead when running Hyprland."
