# Niri + Noctalia Custom Setup

Author: sahilcodexx · Last updated: 2026-09-20 · Status: working on CachyOS / 12th Gen Intel i3-1220P

This document is the source of truth for the Niri + Noctalia desktop configuration under `~/customquickshell/niri/`. Every change made to the system is recorded here so a future agent (or you, on a fresh install) can rebuild the same setup from scratch.

---

## 1. What's in this folder — two siblings, two setups

```
~/customquickshell/niri/
├── mycustomsetup.md                  ← you are here
├── install.sh                        ← re-apply everything in niri/ to the live system
├── niri/                             ← ★ CUSTOM Niri + noctalia setup (this session's work)
│   ├── niri/
│   │   ├── config.kdl                ← niri config → ~/.config/niri/config.kdl
│   │   ├── KEYBINDS.txt              ← quick reference
│   │   └── SOURCE.txt                ← last-sync timestamp
│   ├── noctalia/
│   │   ├── plugins/nightlight-slider/  ← wlsunset driver (slider UI + presets)
│   │   │   ├── plugin.toml
│   │   │   ├── panel.luau
│   │   │   └── service.luau
│   │   └── dotfiles/
│   │       └── xdg-desktop-portal.conf  ← default = gnome (for Niri)
│   └── bin/
│       └── nightlight-set            ← bash helper that kills + restarts wlsunset
└── end4/                             ← ★ Existing end-4/dots-hyprland ii additions (untouched)
    ├── README.md                     ← original end4 README
    ├── restore.sh                    ← original end4 restore script
    ├── bin/
    │   └── github-fetch              ← fetches GitHub contributions for the ii github card
    ├── modules/ii/                   ← QML sidebar modules for end-4 ii
    │   └── sidebarLeft/
    │       ├── AiUsagePanel.qml      ← AI usage panel (Claude/Minimax/Grok/etc.)
    │       └── SidebarLeftContent.qml
    └── patches/                      ← patches applied on top of upstream end-4
        ├── hypr-execs.patch
        └── ii-launcher-search.patch
```

**`niri/`** is everything we built this session for the user's Niri compositor. **`end4/`** is the pre-existing customquickshell content (Hyprland-targeted) — kept here for reference and so the full setup is in one git repo. **They do not interact.** end4 files only apply when running Hyprland with `end-4/dots-hyprland` ii quickshell; niri files only apply when running Niri with noctalia.

---

## 2. The two setups side-by-side

| | **Niri** (this folder) | **Hyprland** (`end-4/dots-hyprland/ii`) |
|---|---|---|
| Compositor | `niri` 26.04 | Hyprland (untouched, `~/.config/hypr/`) |
| Bar/Panel | noctalia v5.1.0 standalone | Quickshell `ii` |
| Night light | noctalia slider plugin → `wlsunset` (this repo) | hyprsunset (Hyprland-only) |
| Clipboard | noctalia clipboard panel + `cliphist` | Quickshell `cliphistService` |
| Wallpaper | `swww` (`Mod+Shift+W`) | `hyprpaper` |
| Launcher | noctalia launcher (`Mod+Space`) | Quickshell launcher (`Super+Space`) |
| Status bar | noctalia top bar | ii top bar |

**Hyprland is NOT to be modified.** It's a separate installation that the user switches between. All edits in this folder are Niri-only.

---

## 3. Niri config — what changed and why

File: `end4/niri/config.kdl` → mirrored at `~/.config/niri/config.kdl`

### 3.1 Environment block (lines 5–17)

| Variable | Value | Reason |
|---|---|---|
| `ELECTRON_OZONE_PLATFORM_HINT` | `auto` | Lets Electron apps pick Wayland when the compositor supports it |
| `NVD_BACKEND` | `direct` | Skip nouveau → nvidia GLVnd dispatch |
| `QT_QPA_PLATFORM` | `wayland` | Force Qt apps to use Wayland |
| `__GL_GSYNC_ALLOWED` | `0` | Disable G-Sync (causes stutter on this Intel iGPU) |
| `__GL_VRR_ALLOWED` | `0` | Disable VRR (Niri handles its own frame pacing) |
| `__NV_PRIME_RENDER_OFFLOAD` | `0` | Not a hybrid graphics laptop |
| `__GLX_VENDOR_LIBRARY_NAME` | `mesa` | Pin to Mesa for Intel iGPU |
| `LIBVA_DRIVER_NAME` | `iHD` | Intel media driver (better than `i965` for newer chips) |
| `QT_STYLE_OVERRIDE` | `adwaita-dark` | Force Adwaita-dark for Qt apps |
| `XCURSOR_THEME` | `Bibata-Modern-Classic` | Match Hyprland cursor |
| `XCURSOR_SIZE` | `24` | Match Hyprland cursor size |

### 3.2 Cursor block (lines 18–21)

```kdl
cursor {
    xcursor-theme "Bibata-Modern-Classic"
    xcursor-size 24
}
```
- Pinned so the compositor's own pointer matches Hyprland. env vars handle apps that read XCURSOR_THEME on their own.

### 3.3 Startup block (lines 23–30)

```kdl
spawn-sh-at-startup "wl-paste --watch cliphist store"   // watch clipboard → cliphist
spawn-at-startup "udiskie"                              // automount tray
spawn-at-startup "/usr/lib/mate-polkit/polkit-mate-authentication-agent-1"  // auth prompts
spawn-sh-at-startup "noctalia -d"                        // noctalia daemon
spawn-sh-at-startup "$HOME/.local/bin/hypr-display-toggle guard"
spawn-at-startup "gnome-keyring-daemon --start --components=secrets"
spawn-at-startup "vicinae server"
```

`hypr-display-toggle` is a script from the previous Hyprland setup that uses `wlr-randr` to remember/restore display configs — kept here because the script works on any wlroots compositor.

### 3.4 Input block (lines 32–52)

```kdl
input {
    keyboard { numlock }
    mouse {
        accel-speed 0.3
        accel-profile "flat"
    }
    focus-follows-mouse
}
```

- `accel-speed 0.3` was bumped from `-0.2` for snappier cursor response (no acceleration curve, just a flat multiplier on top of the input event rate).
- `focus-follows-mouse` matches the Hyprland feel.

### 3.5 Keybinds (lines 195–245)

Every keybind in the config — full reference in `end4/niri/KEYBINDS.txt`. Highlights:

| Keybind | Action |
|---|---|
| `Mod+T` | kitty terminal |
| `Mod+W` | helium AppImage |
| `Mod+C` | zed |
| `Mod+E` | dolphin file manager |
| `Mod+X` | session menu (wlogout) |
| `Mod+I` | noctalia control center |
| `Mod+V` | noctalia clipboard panel (alone, not combined with launcher) |
| `Mod+Space` | noctalia launcher |
| `Mod+N` | notifications panel |
| `Mod+Shift+N` | **night-light slider panel** (custom plugin) |
| `Mod+Shift+W` | random wallpaper via swww |
| `Mod+Shift+S` | region screenshot (`shot-region`) |
| `Mod+Ctrl+C` | volume picker (wpctl status) |
| `Mod+Alt+L` | lock (hyprlock) |
| `Mod+Comma` | noctalia settings |
| `Mod+Alt+R` | toggle screen recording **with system audio** (`rec-with-audio`) |
| `Ctrl+Mod+Alt+R` | toggle screen recording **without audio** (`rec-no-audio`) |
| `Mod+Ctrl+R` | restart noctalia (`noctalia-restart`) |
| `Print` | screenshot UI (niri's built-in) |
| XF86Audio* | volume / mute / mic / media keys via wpctl + playerctl |

Helper scripts referenced from keybinds live in `~/.local/bin/`:
- `shot-region` — `slurp | grim -g - - | wl-copy` (with `--type image/png` fix)
- `shot-window` — `grim -g "$(slurp -w 0 -o)" - | wl-copy` (with `--type image/png` fix)
- `hypr-display-toggle` — display profile switcher (kept from Hyprland era)
- `nightlight-set <temp>` — start wlsunset at the given temp (south-pole polar-night trick)
- `noctalia-restart` — kill+respawn noctalia daemon (recovery helper)
- `rec-with-audio` — toggle recording with `-a default_output -ac opus` via `gpu-screen-recorder -w screen`
- `rec-no-audio` — toggle video-only recording via `gpu-screen-recorder -w screen`

#### Why two `gpu-screen-recorder` wrappers instead of the noctalia plugin?

The noctalia `screen_recorder` plugin reads its `audio_source` from plugin config at
record-start. Its IPC channel (`noctalia msg plugin ... start`) only accepts a
`video_source` override (`focused` | `portal`), not an audio override. So you can't
get two distinct audio behaviours from two keybinds through the plugin alone.

The two scripts use independent PID files (`~/.local/state/rec-{with,no}-audio.pid`)
so the keybinds don't interfere — pressing one stops the recording it started, and
the other can be active at the same time without collision. Outputs land in
`~/Videos/Recordings/rec-{audio,noaudio}-YYYYMMDD-HHMMSS.mp4`.

#### Why `-w screen` (KMS direct) instead of `-w portal`?

Empirically, the xdg-desktop-portal gnome backend drops its ScreenCast interface
after a few `CreateSession` calls in quick succession (the second+ call hangs at
`gsr_capture_portal_setup_dbus: Start`). Since recording hotkeys are by nature
spammed, portal mode flapped under real use. KMS direct (`-w screen`) bypasses the
portal entirely — no permission dialogs, no flapping, no portal restart needed.
Trade-off: it captures the first connected monitor (eDP-1 on laptops) instead of
honouring Wayland's per-output focus; fine for a single-monitor setup, otherwise
swap `-w screen` for the monitor name (`gpu-screen-recorder --list-monitors`).

---

## 4. xdg-desktop-portal — gnome, not hyprland

File: `end4/noctalia/dotfiles/xdg-desktop-portal.conf` → mirrored at `~/.config/xdg-desktop-portal/hyprland-portals.conf`

```ini
[preferred]
default = gnome;gtk
org.freedesktop.impl.portal.FileChooser = kde
```

**Why**: `xdg-desktop-portal-hyprland` only activates under Hyprland. On Niri it stays `inactive (dead)`, which breaks screen capture (Kooha, OBS, Discord screen-share, Firefox screen-share). The GNOME portal is compositor-agnostic — it works on any Wayland with `wlr-screencopy` (which Niri supports).

The file is still named `hyprland-portals.conf` for backward compat with the Hyprland setup, but the `default = gnome` line makes it work on Niri too. If you ever need Hyprland-only extras (picker dialogs, screencopy with damage tracking), swap to `default = hyprland;gtk` on that compositor.

Apply:
```bash
cp ~/customquickshell/niri/end4/noctalia/dotfiles/xdg-desktop-portal.conf \
   ~/.config/xdg-desktop-portal/hyprland-portals.conf
systemctl --user restart xdg-desktop-portal.service
```

---

## 5. Night light plugin (the big custom piece)

The Niri config has no built-in night-light. Noctalia's built-in night light is binary on/off only — no temperature slider. So we built a **local noctalia plugin** that drives `wlsunset` (a tiny Wayland gamma-control daemon) via a polished UI with a slider + presets.

### 5.1 Why wlsunset

- Niri has no native night light.
- `hyprsunset` is Hyprland-only — won't work on Niri.
- `gammastep` is more complex than we need.
- `wlsunset` is a 200KB wlroots-native daemon. With one trick (`-l -89.5 -L 0` to fake a south-pole "polar night" location), it always uses `-t` as a constant temperature — exactly what a slider needs.

### 5.2 Files

- `end4/noctalia/plugins/nightlight-slider/plugin.toml` — manifest, declares panel size `420×280`, registers the plugin
- `end4/noctalia/plugins/nightlight-slider/panel.luau` — UI (header, tinted circle, big temp readout, slider, 4 preset buttons)
- `end4/noctalia/plugins/nightlight-slider/service.luau` — bridges noctalia state ↔ wlsunset via `noctalia.runAsync` + the `nightlight-set` helper
- `end4/bin/nightlight-set` — bash helper: `pkill -x wlsunset && wlsunset -t $TEMP -T $((TEMP+1)) -l -89.5 -L 0`

### 5.3 Panel dimensions (CRITICAL)

The panel size is set in the **manifest**, not the layout code. noctalia's panel surface already applies its own padding via `Style::panelPadding` — adding `padding = ...` in the layout code stacks on top and creates dead space. The manifest:

```toml
[[panel]]
id = "slider"
entry = "panel.luau"
width = 420
height = 280
placement = "floating"
position = "center"
```

If you change the content size, edit `width` / `height` here and `disable` + `enable` the plugin to make noctalia re-read the manifest (file watcher alone won't do it).

### 5.4 Install steps

```bash
# 1. Install wlsunset
sudo pacman -S wlsunset

# 2. Install helper script
mkdir -p ~/.local/bin
cp ~/customquickshell/niri/end4/bin/nightlight-set ~/.local/bin/
chmod +x ~/.local/bin/nightlight-set

# 3. Register a local plugin source inside noctalia
noctalia msg plugins source add local path \
  ~/customquickshell/niri/end4/noctalia/plugins

# (or move the source dir to a git-tracked location first)
# The actual plugin dir lives at:
#   ~/.local/state/noctalia/plugins/sources/local/repo/nightlight-slider/

# 4. Enable the plugin
noctalia msg plugins enable local/nightlight-slider

# 5. Open the panel
# Mod+Shift+N is bound to:
#   noctalia msg panel-toggle local/nightlight-slider:slider
```

### 5.5 How the wlsunset polar-night trick works

`wlsunset` normally reads sun position from lat/long and interpolates between `-t` (night temp) and `-T` (day temp). Without a location, it falls back to a fixed temp using `-t`. With `-l -89.5 -L 0` (south pole, prime meridian):

- South pole is in **polar night** from late March through late September (a ~6-month stretch of "always dark")
- During polar night, wlsunset always uses `-t`
- We set `-T $((TEMP+1))` to satisfy wlsunset's "high > low" validation, but it's never reached
- Net effect: wlsunset applies `-t` as a constant temperature regardless of actual time

**Caveat**: this breaks near the Sep/equinox. If the south pole flips to midnight sun (after Sep 22), swap to `-l 89.5 -L 0` (north pole) which is the opposite season. Or use `-S 23:59 -s 23:59 -d 0` for manual sunrise/sunset.

### 5.6 Plugin runtime gotchas (learned the hard way)

| Bug | Cause | Fix |
|---|---|---|
| Wlsunset blinks every second | `update()` re-applies state on every tick, killing + respawning wlsunset | Track `lastAppliedEnabled` / `lastAppliedTemp` in service; `apply()` returns early if unchanged |
| `apply()` resets `enabled=false` on every tick | Initial `update()` runs before user has touched the panel | Add `inited` flag so `update()` only seeds config once; subsequent ticks do nothing |
| `ui.slider` / `ui.toggle` don't fire onChange | These widgets want a **closure**, not a string callback name | `onChange = function(value) ... end` (not `onChange = "onSliderChange"`) |
| Panel renders but with massive empty space | Default panel min-height is way larger than your content | Declare `width` / `height` in the **manifest**, not in the layout |
| Layout padding adds extra dead space | noctalia's surface already pads | Don't set `padding = ...` on the outer column — let `Style::panelPadding` handle it |

---

## 6. End-to-end install from a fresh CachyOS

```bash
# ---------- SYSTEM ----------
sudo pacman -S wlsunset

# ---------- NIRI CONFIG ----------
mkdir -p ~/.config/niri
cp ~/customquickshell/niri/end4/niri/config.kdl ~/.config/niri/config.kdl

# ---------- CLIPBOARD ----------
# wl-paste --watch cliphist store is already in the niri spawn-at-startup block.
# Install cliphist if needed: sudo pacman -S cliphist wl-clipboard

# ---------- NIGHT LIGHT ----------
mkdir -p ~/.local/bin
cp ~/customquickshell/niri/end4/bin/nightlight-set ~/.local/bin/
chmod +x ~/.local/bin/nightlight-set

# Set up the local plugin source directory
mkdir -p ~/.local/state/noctalia/plugins/sources/local/repo
cp -r ~/customquickshell/niri/end4/noctalia/plugins/nightlight-slider \
      ~/.local/state/noctalia/plugins/sources/local/repo/

cd ~/.local/state/noctalia/plugins/sources/local/repo
git init && git add . && git -c user.email=local@local -c user.name=local \
    commit -m "nightlight-slider initial"

noctalia msg plugins source add local path \
  ~/.local/state/noctalia/plugins/sources/local/repo
noctalia msg plugins enable local/nightlight-slider

# ---------- PORTAL (for Kooha, OBS, screen-share) ----------
cp ~/customquickshell/niri/end4/noctalia/dotfiles/xdg-desktop-portal.conf \
   ~/.config/xdg-desktop-portal/hyprland-portals.conf
systemctl --user restart xdg-desktop-portal.service

# ---------- KEYBIND SNAPSHOT (already in config.kdl) ----------
# Mod+Shift+N     → opens the night light slider panel
# Mod+V           → noctalia clipboard panel (no launcher)
# Mod+Space       → noctalia launcher
# Mod+Alt+R       → toggle screen recording WITH system audio
# Ctrl+Mod+Alt+R  → toggle screen recording WITHOUT audio (video-only)
# Mod+Ctrl+R      → restart noctalia (recovery helper)
```

After install, restart noctalia or log out/in for the keybinds to take effect.

---

## 7. Discord (Electron apps) on Niri

Electron apps default to **Vulkan + Wayland**, which Niri's wlroots refuses with:

```
[ERROR] '--ozone-platform=wayland' is not compatible with Vulkan.
        Consider switching to '--ozone-platform=x11' or disabling Vulkan
```

If Discord (or any Electron app — VS Code, Obsidian, etc.) opens a process but never shows a window, that's why.

**Fix**: drop a wrapper at `~/.local/bin/<app>` that exec's the system binary with `--disable-gpu`:

```bash
#!/usr/bin/env bash
exec /usr/bin/<app> --disable-gpu --no-sandbox "$@"
```

**Caveat**: launchers read `~/.local/share/applications/<app>.desktop`, which has `Exec=/usr/bin/<app>` hardcoded — that bypasses your `~/.local/bin` wrapper entirely. To override the launcher path, copy the system .desktop to your user dir and edit `Exec`:

```bash
cp /usr/share/applications/discord.desktop ~/.local/share/applications/
sed -i 's|Exec=/usr/bin/discord|Exec=/home/USER/.local/bin/discord|' \
    ~/.local/share/applications/discord.desktop
update-desktop-database ~/.local/share/applications/
```

---

## 8. Cursor theme consistency

Set in three places so the cursor matches across compositor, new apps, and GTK apps:
1. `~/.config/niri/config.kdl` → `cursor { xcursor-theme "Bibata-Modern-Classic"; xcursor-size 24 }` — the compositor cursor
2. `~/.config/niri/config.kdl` → `environment { XCURSOR_THEME "Bibata-Modern-Classic"; XCURSOR_SIZE "24" }` — apps that read env vars
3. `~/.config/gtk-3.0/settings.ini` and `~/.config/gtk-4.0/settings.ini` — GTK apps (NOT yet set in this repo; add `[Settings] cursor-theme-name=Bibata-Modern-Classic cursor-size=24` if GTK apps show the wrong cursor)

---

## 9. Things that are NOT in this repo (out of scope)

- Hyprland setup — `~/.config/hypr/` is untouched. End-4 ii quickshell lives there.
- noctalia's own built-in plugin sources (`~/.local/state/noctalia/plugins/sources/community/`, `official/`, `xevrion/`) — those are git-checkouts of upstream repos, not custom code.
- The user's `~/.local/bin/` helper scripts (`shot-region`, `shot-window`, `hypr-display-toggle`) — those were created in earlier sessions and live in the user's `~/.local/bin/`.

---

## 10. Quick commands cheat sheet

```bash
# Open the night light slider panel
noctalia msg panel-toggle local/nightlight-slider:slider

# Re-fetch the GitHub contributions heatmap data
noctalia msg plugin xevrion/github-contributions:fetcher all refresh

# Check wlsunset is running
pgrep -af wlsunset

# Force-set night light temp from the command line
~/.local/bin/nightlight-set 3500   # warm
~/.local/bin/nightlight-set 4500   # cozy
~/.local/bin/nightlight-set 6500   # off

# Restart the screen capture portal if Kooha / OBS misbehaves
systemctl --user restart xdg-desktop-portal.service

# Check noctalia plugin errors
tail -f ~/.cache/noctalia/noctalia.log | grep -iE "error|nightlight"
```
