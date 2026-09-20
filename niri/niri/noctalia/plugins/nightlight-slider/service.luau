--!nonstrict
-- Service: bridges noctalia state to the wlsunset helper script. The panel
-- publishes "enabled" and "temp" into state; this service reads them and
-- shells out to `nightlight-set` (which kills any running wlsunset and
-- starts a fresh one with the new temperature).
--
-- Guard against redundant restarts: only kill+spawn wlsunset when the desired
-- (enabled, temp) tuple actually changed since the last apply. Otherwise
-- update() would blink wlsunset on every periodic tick.

local inited = false
local enabled = false
local temp = nil
local lastAppliedEnabled = nil
local lastAppliedTemp = nil

local function trim(s)
  return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

local function runSet(value)
  if not noctalia.commandExists("nightlight-set") then
    noctalia.log("nightlight-slider: nightlight-set script not found in PATH")
    return
  end
  noctalia.runAsync({ "nightlight-set", tostring(value) }, function(result)
    if result.exitCode ~= 0 then
      noctalia.log("nightlight-slider: helper failed (exit " .. tostring(result.exitCode) .. "): " .. tostring(result.stderr or ""))
    end
  end)
end

local function apply()
  if enabled == lastAppliedEnabled and temp == lastAppliedTemp then
    return
  end
  lastAppliedEnabled = enabled
  lastAppliedTemp = temp

  if enabled and temp then
    runSet(temp)
  else
    noctalia.runAsync({ "pkill", "-x", "wlsunset" }, function() end)
  end
end

local function initFromConfig()
  if inited then return end
  inited = true
  enabled = noctalia.getConfig("default_enabled") and true or false
  temp = tonumber(noctalia.getConfig("default_temp"))
  -- First apply() will see lastAppliedEnabled=nil and trigger.
end

function update()
  initFromConfig()
  apply()
end

function onEnable()
  inited = false
  lastAppliedEnabled = nil
  lastAppliedTemp = nil
  initFromConfig()
  apply()
end

function onConfigChanged()
  local newEnabled = noctalia.getConfig("default_enabled") and true or false
  local newTemp = tonumber(noctalia.getConfig("default_temp"))
  if newEnabled ~= enabled or newTemp ~= temp then
    enabled = newEnabled
    temp = newTemp
    apply()
  end
end

noctalia.state.watch("enabled", function(value)
  enabled = value and true or false
  inited = true
  apply()
end)

noctalia.state.watch("temp", function(value)
  temp = tonumber(trim(tostring(value or "")))
  inited = true
  if enabled and temp then
    apply()
  end
end)

function onIpc(event, payload)
  if event == "set" then
    local ok, data = pcall(noctalia.json.decode, payload or "{}")
    if ok and type(data) == "table" then
      if data.enabled ~= nil then enabled = data.enabled and true or false end
      if data.temp ~= nil then temp = tonumber(data.temp) end
      inited = true
      apply()
    end
  end
end
