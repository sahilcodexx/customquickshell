#!/usr/bin/env bash
# restore.sh — restore screentime-card + github-card from this repo.
# Idempotent: safe to re-run. Existing files are overwritten.
set -euo pipefail

REPO="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"

echo "==[1/5]== Copying screentime-card qml"
mkdir -p "${HOME_DIR}/.config/quickshell/screentime-card"
cp -v "${REPO}/screens/screentime-card/shell.qml"        "${HOME_DIR}/.config/quickshell/screentime-card/"
cp -v "${REPO}/screens/screentime-card/ScreentimeCard.qml" "${HOME_DIR}/.config/quickshell/screentime-card/"

echo "==[2/5]== Copying github-card qml"
mkdir -p "${HOME_DIR}/.config/quickshell/github-card"
cp -v "${REPO}/screens/github-card/shell.qml"        "${HOME_DIR}/.config/quickshell/github-card/"
cp -v "${REPO}/screens/github-card/GithubCard.qml"  "${HOME_DIR}/.config/quickshell/github-card/"

echo "==[3/5]== Copying github-fetch script"
cp -v "${REPO}/bin/github-fetch" "${HOME_DIR}/.local/bin/github-fetch"
chmod +x "${HOME_DIR}/.local/bin/github-fetch"

echo "==[4/5]== Patching ii/services/LauncherSearch.qml (idempotent)"
SEARCH_FILE="${HOME_DIR}/.config/quickshell/ii/services/LauncherSearch.qml"
if [[ -f "${SEARCH_FILE}" ]]; then
    # Apply patch (skip if already applied)
    if grep -q '/github"' "${SEARCH_FILE}" 2>/dev/null; then
        echo "    already patched, skipping"
    elif patch -p1 --dry-run -d "$(dirname "${SEARCH_FILE}")" \
        < "${REPO}/patches/ii-launcher-search.patch" >/dev/null 2>&1; then
        patch -p1 -d "$(dirname "${SEARCH_FILE}")" < "${REPO}/patches/ii-launcher-search.patch"
        echo "    patched"
    else
        echo "    WARNING: patch would not apply cleanly — check ${SEARCH_FILE}"
    fi
else
    echo "    file not found, skipping"
fi

echo "==[5/5]== Patching hypr/custom/execs.lua (idempotent)"
EXEC_FILE="${HOME_DIR}/.config/hypr/custom/execs.lua"
if [[ -f "${EXEC_FILE}" ]]; then
    if grep -q 'screentime-card' "${EXEC_FILE}" 2>/dev/null; then
        echo "    already patched, skipping"
    elif patch -p1 --dry-run -d "$(dirname "${EXEC_FILE}")" \
        < "${REPO}/patches/hypr-execs.patch" >/dev/null 2>&1; then
        patch -p1 -d "$(dirname "${EXEC_FILE}")" < "${REPO}/patches/hypr-execs.patch"
        echo "    patched"
    else
        echo "    WARNING: patch would not apply cleanly — check ${EXEC_FILE}"
    fi
else
    echo "    file not found, skipping"
fi

cat <<'EOF'

==[done]==
Restart the Quickshell shells to pick up changes:
  pkill -f 'qs -c ii'; qs -c ii &
  pkill -f 'screentime-card'; qs -p ~/.config/quickshell/screentime-card &
  pkill -f 'github-card';    qs -p ~/.config/quickshell/github-card &
Then type /screentime or /github in the launcher.
EOF
