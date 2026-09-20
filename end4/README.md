# customquickshell — AI Usage Sidebar for end-4 dots-hyprland (ii)

Pixel-perfect, wallpaper-synced **AI Usage** tab for the left sidebar (`Super + A` / `Super + O`) — extracted from [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) `ii` panel family and hard-fixed for real-world use.

> **Why this fork?** The upstream `AiUsagePanel.qml` merges cards into the background from a distance, bars are hardcoded `#b9c7bf` (invisible in dark), dates go stale (`Mon 17-23` when today is `25`), and `opencode/minimax/grok` have no live collectors. This repo fixes all of that and adds **Minimax** + **Grok** + **Opencode** live parsing from `~/.local/share/opencode/opencode.db` and `~/.minimax/v2/sqlite/runtime-state.sqlite`.

![AI Usage — 6 providers, live bars, adaptive dark/light](docs/screenshot-usage.png)

---

## Features — what’s fixed vs upstream

| Area | Upstream bug | Fix in this fork |
|------|--------------|------------------|
| **Cards washout** | `colLayer2Base` (`1.05` contrast) vs `colLayer1` — invisible from distance | `Card: m3surfaceContainer` + `1px outlineVariant@0.55` border + `InsightTile: m3surfaceContainerHigh@0.6` — `1.45→1.97` contrast, visible in light/dark |
| **Dropdown merged** | `Opencode` selector `colLayer2Base` no border, looks like text | `Item + Rectangle colLayer2 + 1px border@0.70` + `RippleButton transparent` |
| **Bars** | Hardcoded `#b9c7bf` — light green vs light gray `1.03` in dark, `Mon 17-23` stale | Adaptive track `m3outlineVariant` (`#bfc9c3` light / `#49464a` dark) + light `#d0dcd5` `1.97` vs card, `colPrimary` fill (`#176b53` light / mint dark `5.48`) |
| **Dates stale** | `opencode.json` ended `23` when today `25` | `agent-usage-opencode` now queries `message.data.tokens` per `date(time_created,'localtime')` and `AiUsagePanel.days` always generates last 7 calendar days filling `0` |
| **`Current usage 0` while using Opencode** | Grouped `session.time_created` — active session created `24` counted on `24` even when used `25` | Group by `message.time_created` so today `25` shows `10.0M` |
| **Today `0` on Minimax/IST** | `date(ts/1000,'unixepoch')` UTC → `24 23:00 UTC` = `25 IST` counted as `24` | `date(ts/1000,'unixepoch','localtime')` — `Grok 6K / Minimax 52M` now correct for IST |
| **Top models 5 → 3** | Shows 5 (Big Pickle `3.1K`) | `model: root.models.slice(0,3)` — only top 3 |
| **Huge gap `Current usage --- logo`** | `RowLayout fillWidth` left + `48px` right gap | `Item` with `anchors.centerIn` truly centered `7.1M`, left `current usage` one-line `102px +6px` margin, right `36px` logo overlay |
| **Dark `83M` invisible** | Forced `Card #e9efea` light on dark → white on white | Back to adaptive `m3surfaceContainer` (`#e9efea`/`#201f20`) + `m3surfaceContainerHigh` |
| **Providers 4 → 6** | `aiUsageProviders` missing `minimax`, no `grok.json` | Added `minimax,grok` + collectors `agent-usage-minimax` (reads `~/.minimax/v2/sqlite/runtime-state.sqlite: local_runtime_token_usage`) + `agent-usage-grok` (reads `~/.grok/grok.db: sessions` `grok-4.3`) + `agent-usage-opencode` (reads `~/.local/share/opencode/opencode.db: message/session`) |
| **Auto-refresh** | `aiUsageAutoRefresh false` `30m` — stale until manual `Refresh` | `true` `15m` + `isStale()` (`last date != today` or `>refreshInterval`) auto `refreshAll` on `Component.onCompleted`/`onProviderChanged` + always-7-days `days` map |

---

## Supported providers (live)

- **Opencode** — `~/.local/share/opencode/opencode.db` (`session` + `message` JSON tokens)
- **Minimax** (`mcode` at `~/.minimax-code/bin/mcode`) — `~/.minimax/v2/sqlite/runtime-state.sqlite`
- **Grok** (`~/.grok/bin/grok`) — `~/.grok/grok.db` `sessions` (`grok-4.3`)
- **Claude** — `~/.claude/projects` + OAuth `api.anthropic.com`
- **Codex** — Codex CLI sessions
- **Antigravity** — local stats
- `Cursor/Copilot` ready via `AgentUsageSettings`

All collectors are `scripts/agent-usage-*` executables picked up by `scripts/agent-usage-update` (the `Refresh` button runs `agent-usage-update --force`).

---

## Install — drop-in to existing `ii` dots

### 1. Backup
```bash
cp ~/.config/quickshell/ii/modules/ii/sidebarLeft/AiUsagePanel.qml{,.bak}
cp ~/.config/quickshell/ii/services/AgentUsage.qml{,.bak}
cp ~/.config/quickshell/ii/services/AgentUsageSettings.qml{,.bak}
```

### 2. Copy this repo
```bash
git clone https://github.com/sahilcodexx/customquickshell.git /tmp/custom
cp /tmp/custom/modules/ii/sidebarLeft/AiUsagePanel.qml ~/.config/quickshell/ii/modules/ii/sidebarLeft/
cp /tmp/custom/modules/ii/sidebarLeft/SidebarLeftContent.qml ~/.config/quickshell/ii/modules/ii/sidebarLeft/
cp /tmp/custom/services/AgentUsage.qml ~/.config/quickshell/ii/services/
cp /tmp/custom/services/AgentUsageSettings.qml ~/.config/quickshell/ii/services/
cp /tmp/custom/scripts/agent-usage-* ~/.config/quickshell/ii/scripts/
chmod +x ~/.config/quickshell/ii/scripts/agent-usage-*
# logos (uses ~/Downloads/agentslogo)
mkdir -p ~/Downloads/agentslogo
# ensure grok.svg, minimax.svg, opencode.svg etc exist (see logo() in AiUsagePanel)
```

### 3. Enable Minimax/Grok if you use them
`services/AgentUsageSettings.qml:5` already includes `minimax,grok`:
```qml
property string aiUsageProviders: "claude,codex,antigravity,cursor,copilot,grok,opencode,minimax"
```

### 4. Reload
```bash
qs -c ii ipc call search close 2>/dev/null; pkill -9 qs; qs -c ii & disown
# or
hyprctl reload
# then Super + A (Usage tab) — Refresh if needed
~/.config/quickshell/ii/scripts/agent-usage-update --force
cat ~/.local/state/quickshell/agents/usage/*.json | jq .recentDays
```

### Ghostty + Kitty wallpaper sync (bonus in this repo's history)
- `kitty.conf: background_opacity 0.90` `window_margin_width 22`
- `ghostty/config.ghostty: background-opacity 0.90 + blur 5/false + config-file auto/theme.ghostty`
- `hypr/custom/rules.lua: opacity "0.90 0.90"` for `com.mitchellh.ghostty` (fixes Hyprland 0.55 alpha container ghostty#3449)
- `scripts/colors/terminal/ghostty-theme` + `applycolor.sh:apply_ghostty()` generates both `kitty-theme.conf` and `ghostty/auto/theme.ghostty` from `material_colors.scss` on wallpaper change.

Default terminal stays `kitty -1` (`illogical-impulse/config.json: terminal`).

---

## File map

```
customquickshell/
├─ modules/ii/sidebarLeft/AiUsagePanel.qml      # ← the 500-line Wayland panel (cards, bars, 7-day fix, isStale auto-refresh, centered 7.1M)
├─ modules/ii/sidebarLeft/SidebarLeftContent.qml # tab bar wrapper
├─ services/AgentUsage.qml                      # discovery + weekPeak + refresh
├─ services/AgentUsageSettings.qml              # showAiUsage / aiUsageProviders / autoRefresh 15m
└─ scripts/
   ├─ agent-usage-update          # dispatcher (picks up agent-usage-*)
   ├─ agent-usage-opencode        # NEW — message.data.tokens per localtime
   ├─ agent-usage-minimax         # NEW — minimax sqlite localtime
   ├─ agent-usage-grok            # NEW — grok.db sessions
   ├─ agent-usage-claude
   ├─ agent-usage-codex
   └─ agent-usage-antigravity
```

---

## Restoring if deleted

```bash
git clone https://github.com/sahilcodexx/customquickshell.git
# follow Install steps above
```

---

## Credits

- Upstream: [end-4/dots-hyprland](https://github.com/end-4/dots-hyprland) (`ii` panel family, Material 3)
- Fixes & collectors: `sahilcodexx` + Muse Spark
- Terminal sync: `matugen` + `quickShell` `applycolor.sh`

## License

Same as upstream dots-hyprland (MIT/GPL-3.0 where applicable) — use freely, keep wallpaper sync.

---
*Teams: Opencode Zen · Muse Spark 1.2 · Grok 4.3 · Minimax M2 · Codex*
*Tested on CachyOS / Hyprland 0.56.2 / quickshell `c9e7e286dee679eeee854188de70c78f` / Ghostty 1.3.1 / Kitty 0.48.2*
