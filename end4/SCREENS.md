# Screens — screentime + github cards

Two standalone Quickshell cards that open via the launcher search (`/screentime`, `/github`) and live alongside the `ii` shell. Both read wallpaper colors at runtime to stay synced with end-4's matugen pipeline.

## Layout

```
customquickshell/
├── screens/
│   ├── screentime-card/        # /screentime — Habit-style productivity heatmap
│   │   ├── shell.qml           # PanelWindow + IpcHandler (toggle/open/close)
│   │   └── ScreentimeCard.qml  # card UI — heatmap, 7-day list, total
│   └── github-card/            # /github — contributions, repos, PRs, actions
│       ├── shell.qml
│       └── GithubCard.qml      # 4 tabs: Overview / Inbox / Pulls / Actions
├── bin/
│   └── github-fetch            # Python data fetcher (cached 5min, polls `gh`)
├── patches/
│   ├── ii-launcher-search.patch  # adds /screentime + /github search actions
│   └── hypr-execs.patch          # autostarts the two card shells
└── restore.sh                  # idempotent restore — see "Setup" below
```

## Setup

```sh
cd /home/sahilcodex/customquickshell
./restore.sh
```

What `restore.sh` does:
1. Copies `screens/screentime-card/*` → `~/.config/quickshell/screentime-card/`
2. Copies `screens/github-card/*` → `~/.config/quickshell/github-card/`
3. Copies `bin/github-fetch` → `~/.local/bin/github-fetch` (chmod +x)
4. Applies `patches/ii-launcher-search.patch` to `~/.config/quickshell/ii/services/LauncherSearch.qml` (idempotent — skips if already patched)
5. Applies `patches/hypr-execs.patch` to `~/.config/hypr/custom/execs.lua` (idempotent)

Then restart:
```sh
pkill -f 'qs -c ii';           qs -c ii &
pkill -f 'screentime-card';    qs -p ~/.config/quickshell/screentime-card &
pkill -f 'github-card';        qs -p ~/.config/quickshell/github-card &
```

## Screentime card

- Reads `~/.local/bin/screentime --export {today,week,all}` every 15s
- 1Hz in-card tick so the displayed total feels live between daemon samples
- Hover any heatmap cell → tooltip with date + duration
- Click ×, press Escape, or click outside to dismiss
- Themed by `~/.local/state/quickshell/user/generated/colors.json` (matugen)

Requires `screentime` daemon running:
```sh
systemctl --user status screentime.service
```

## GitHub card

- Reads `~/.local/state/quickshell/github-card/cache.json` (refreshed by `github-fetch` every 5min)
- `github-fetch` calls `gh api user`, `gh api graphql` (contributions), `gh api user/repos`, `gh api notifications`, `gh search prs`
- Tabs:
  - **Overview**: 53-week contribution heatmap + 4 stat cards (CONTRIBS/STARS/FOLLOWERS/STREAK) + top 4 repos
  - **Inbox**: notifications
  - **Pulls**: open PRs authored by you (clickable)
  - **Actions**: recent workflow runs across top 5 pushed repos
- Keys: `1-4` switch tabs, `R` refresh, `Esc` close

Requires `gh` CLI authenticated:
```sh
gh auth status
```

## To remove

```sh
pkill -f 'screentime-card'
pkill -f 'github-card'
rm -rf ~/.config/quickshell/screentime-card
rm -rf ~/.config/quickshell/github-card
rm ~/.local/bin/github-fetch
# Then un-apply the patches — see git log for the exact insertions
git show HEAD:patches/ii-launcher-search.patch
git show HEAD:patches/hypr-execs.patch
```
