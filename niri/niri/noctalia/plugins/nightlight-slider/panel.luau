--!nonstrict
-- Panel: a toggle + slider to drive wlsunset's color temperature.
-- Publishes "enabled" and "temp" into noctalia state; the service applies
-- them via the nightlight-set helper script.

local minTemp = tonumber(noctalia.getConfig("min_temp")) or 1500
local maxTemp = tonumber(noctalia.getConfig("max_temp")) or 6500

local enabled = noctalia.state.get("enabled")
if enabled == nil then
  enabled = noctalia.getConfig("default_enabled") or false
end
local temp = noctalia.state.get("temp")
if type(temp) ~= "number" then
  temp = tonumber(noctalia.getConfig("default_temp")) or 4500
end

local function commit()
  noctalia.state.set("enabled", enabled)
  noctalia.state.set("temp", temp)
end

local function describe(t)
  if not enabled then return "Off" end
  if t >= 6000 then return "Daylight" end
  if t >= 5200 then return "Subtle" end
  if t >= 4500 then return "Cozy" end
  if t >= 3800 then return "Warm" end
  if t >= 3000 then return "Evening" end
  if t >= 2200 then return "Amber" end
  return "Candlelight"
end

local function tintHex(t)
  local range = math.max(1, maxTemp - minTemp)
  local warmth = (maxTemp - t) / range
  if warmth < 0 then warmth = 0 end
  if warmth > 1 then warmth = 1 end
  local r = 1.0
  local g = 0.78 + warmth * (0.48 - 0.78)
  local b = 0.75 + warmth * (0.10 - 0.75)
  local function toHex(v)
    return string.format("%02x", math.floor(v * 255 + 0.5))
  end
  return "#" .. toHex(r) .. toHex(g) .. toHex(b)
end

-- Each preset is one cell of a single horizontal row. Labels are short on
-- purpose so 4 fit in one line without truncation.
local PRESETS = {
  { label = "Day",    temp = 6500, enabled = false },
  { label = "Cozy",   temp = 4500, enabled = true  },
  { label = "Warm",   temp = 3500, enabled = true  },
  { label = "Candle", temp = 2200, enabled = true  },
}

local function applyPreset(p)
  temp = p.temp
  enabled = p.enabled
  commit()
end

local function presetButton(p)
  local isActive = enabled == p.enabled and math.abs(temp - p.temp) < 50
  return ui.button({
    key = "preset_" .. p.label,
    text = p.label,
    variant = isActive and "primary" or "ghost",
    onClick = function() applyPreset(p) end,
  })
end

local function panelContent()
  local currentLabel = describe(temp)
  -- noctalia's panel surface already applies its own padding (Style::panelPadding).
  -- Don't add layout padding here — it stacks on top and creates dead space.
  return ui.column({ flexGrow = 1, gap = 12 }, {
    -- Header: status dot + title (left), toggle (right).
    ui.row({ justify = "space_between", align = "center" }, {
      ui.row({ gap = 10, align = "center" }, {
        ui.box({
          width = 10,
          height = 10,
          radius = 5,
          fill = enabled and tintHex(temp) or "on_surface_variant",
          opacity = enabled and 1.0 or 0.4,
        }),
        ui.label({ text = "Night Light", fontSize = 15, fontWeight = "bold" }),
      }),
      ui.toggle({
        key = "nightlight_toggle",
        checked = enabled,
        onChange = function(value)
          enabled = value == true or value == "true"
          commit()
        end,
      }),
    }),

    -- Big readout: tinted circle + temp + descriptor.
    ui.row({ align = "center", gap = 14 }, {
      ui.box({
        width = 44,
        height = 44,
        radius = 22,
        fill = tintHex(temp),
        borderColor = "outline_variant",
        borderWidth = 1,
      }),
      ui.column({ gap = 2 }, {
        ui.label({
          text = tostring(math.floor(temp)) .. "K",
          fontSize = 24,
          fontWeight = "bold",
          color = "on_surface",
        }),
        ui.label({
          text = currentLabel,
          fontSize = 12,
          color = enabled and "primary" or "on_surface_variant",
        }),
      }),
    }),

    -- Slider with directional labels.
    ui.column({ gap = 6 }, {
      ui.slider({
        key = "nightlight_slider",
        min = minTemp,
        max = maxTemp,
        step = 100,
        value = temp,
        onChange = function(value)
          local n = tonumber(value)
          if n == nil then return end
          if n < minTemp then n = minTemp end
          if n > maxTemp then n = maxTemp end
          temp = n
          if not enabled then enabled = true end
          commit()
        end,
      }),
      ui.row({ justify = "space_between" }, {
        ui.label({ text = "Warm " .. tostring(minTemp) .. "K", fontSize = 10, color = "on_surface_variant" }),
        ui.label({ text = "Cool " .. tostring(maxTemp) .. "K", fontSize = 10, color = "on_surface_variant" }),
      }),
    }),

    ui.separator({ height = 1 }),

    -- Preset row: 4 short-label buttons in a single horizontal line.
    ui.row({ gap = 6 }, {
      presetButton(PRESETS[1]),
      presetButton(PRESETS[2]),
      presetButton(PRESETS[3]),
      presetButton(PRESETS[4]),
    }),
  })
end

function onOpen(_context)
  panel.render(panelContent())
end

noctalia.state.watch("enabled", function(value)
  enabled = value and true or false
  panel.render(panelContent())
end)

noctalia.state.watch("temp", function(value)
  local n = tonumber(value)
  if n then temp = n end
  panel.render(panelContent())
end)
