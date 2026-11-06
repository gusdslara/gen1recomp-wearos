-- Voxel Diorama (Gen 3): a 3D diorama overworld for FireRed, LeafGreen,
-- Ruby, Sapphire and Emerald.
--
-- The map is rebuilt as 4px voxels from the cart's own collision grid and
-- textured by the live flat render, so every tileset, animation, door and
-- weather effect carries over without per-map assets.  See README.md.

return function(mod)
  if mod.generation ~= nil and mod.generation ~= 3 then
    mod.log:warn("Voxel Diorama (Gen 3) only runs on Gen 3 games; nothing installed")
    return
  end

  local cache = {}
  local function use(name)
    local loaded = cache[name]
    if loaded ~= nil then return loaded end
    local path = "voxel/" .. name .. ".lua"
    local source = assert(mod:read(path), "missing " .. path)
    local chunk = assert(load(source, "@voxel_world_gen3/" .. path))
    loaded = chunk(use)
    cache[name] = loaded
    return loaded
  end

  -- (wear port) the 3D code is only loaded the first time the view is
  -- switched on, so a game that stays 2D pays nothing for it: no voxel
  -- modules in memory, no hooks in the field renderer, no per-frame work.
  local Bridge = nil
  local function bridge()
    if Bridge then return Bridge end
    Bridge = use("bridge")
    -- learned street-lamp tiles survive a restart (bridge.lua)
    if mod.cache then Bridge.setCache(mod.cache) end
    Bridge.setLogger(function(level, fmt, ...)
      local f = mod.log[level] or mod.log.info
      f(mod.log, fmt, ...)
    end)
    -- anything that stops the view on this device goes to the mod manager's
    -- error feed as well as the on-screen notice
    Bridge.setReporter(function(message)
      local ok, Runtime = pcall(require, "src.mods.Runtime")
      if ok and Runtime and Runtime.reportError then
        Runtime.reportError("voxel_world_gen3", message)
      end
    end)
    return Bridge
  end

  local LEVELS = { OFF = 0, LOW = 1, MID = 2, HIGH = 3 }

  -- (wear port) every default is the lightest setting: a watch GPU and
  -- battery.  Raise them in OPTIONS > MODS if the watch keeps up.
  mod.options:define({
    { key = "mode", label = "VOXEL VIEW", type = "choice", default = "OFF",
      choices = { { "OFF", "OFF" }, { "LOW", "LOW" }, { "MID", "MID" }, { "HIGH", "HIGH" } } },
    { key = "quality", label = "VOXEL QUALITY", type = "choice", default = "potato",
      choices = { { "AUTO", "auto" }, { "HIGH", "high" }, { "BALANCED", "balanced" }, { "POTATO", "potato" } } },
    { key = "height", label = "VOXEL HEIGHT", type = "choice", default = "100",
      choices = { { "75%", "75" }, { "100%", "100" }, { "125%", "125" }, { "150%", "150" } } },
    { key = "resolution", label = "VOXEL RES", type = "choice", default = "pixel",
      choices = { { "AUTO", "auto" }, { "FULL", "full" }, { "HALF", "half" }, { "PIXEL", "pixel" } } },
    { key = "yaw", label = "CAMERA TURN", type = "choice", default = "0",
      choices = { { "LEFT 30", "-30" }, { "LEFT 15", "-15" }, { "STRAIGHT", "0" },
                  { "RIGHT 15", "15" }, { "RIGHT 30", "30" } } },
    { key = "zoom", label = "VOXEL ZOOM", type = "choice", default = "100",
      choices = { { "100%", "100" }, { "125%", "125" }, { "150%", "150" },
                  { "175%", "175" }, { "200%", "200" } } },
    { key = "indoorZoom", label = "INDOOR ZOOM", type = "choice", default = "fit",
      choices = { { "FIT", "fit" }, { "OFF", "off" } } },
    { key = "relief", label = "LEAF RELIEF", type = "toggle", default = false },
    { key = "sunShadows", label = "SUN SHADOWS", type = "toggle", default = false },
    { key = "weather3d", label = "3D WEATHER", type = "toggle", default = false },
    { key = "daynight", label = "DAY/NIGHT", type = "choice", default = "off",
      choices = { { "GAME CLOCK", "game" }, { "DEVICE CLOCK", "device" }, { "OFF", "off" } } },
    { key = "blur", label = "DISTANCE BLUR", type = "toggle", default = false },
    { key = "roundTrees", label = "ROUND TREES", type = "toggle", default = false },
    { key = "treeStyle", label = "TREE STYLE", type = "choice", default = "classic",
      choices = { { "CLASSIC", "classic" }, { "ROUNDED", "rounded" }, { "ROUNDED+", "roundedplus" } } },
    { key = "roofs", label = "SLOPED ROOFS", type = "toggle", default = false },
    { key = "solid", label = "SOLID CHARACTERS", type = "choice", default = "0",
      choices = { { "OFF", "0" }, { "THIN", "2" }, { "SLAB", "3" }, { "THICK", "5" } } },
    { key = "breath", label = "BREATH", type = "choice", default = "off",
      choices = { { "OFF", "off" }, { "SUBTLE", "subtle" }, { "NORMAL", "normal" } } },
    { key = "blink", label = "BLINK", type = "toggle", default = false },
    { key = "nightlights", label = "NIGHT LIGHTS", type = "toggle", default = false },
    { key = "reflect", label = "REFLECTIONS", type = "toggle", default = false },
    { key = "sway", label = "SWAYING TREES", type = "toggle", default = false },
    { key = "critters", label = "FIREFLIES & BIRDS", type = "toggle", default = false },
    { key = "smoke", label = "CHIMNEY SMOKE", type = "toggle", default = false },
    { key = "footprints", label = "FOOTPRINTS", type = "toggle", default = false },
    { key = "clouds", label = "CLOUDS & STARS", type = "toggle", default = false },
    { key = "waves", label = "WAVES & FOAM", type = "toggle", default = false },
    { key = "caveFx", label = "CAVE ATMOSPHERE", type = "toggle", default = false },
    { key = "falls", label = "WATERFALLS", type = "toggle", default = false },
    { key = "wholeMaps", label = "BUILD AHEAD", type = "toggle", default = true },
    { key = "nearMaps", label = "BUILD NEIGHBOURS", type = "toggle", default = false },
    { key = "prebuild", label = "PRE-BUILD AT START", type = "toggle", default = false },
    { key = "shadows", label = "SHADOWS", type = "toggle", default = false },
    { key = "xray", label = "SEE-THROUGH", type = "toggle", default = false },
    { key = "rate", label = "3D RATE", type = "choice", default = "half",
      choices = { { "AUTO", "auto" }, { "FULL", "full" }, { "HALF", "half" } } },
    { key = "perf", label = "PERF STATS", type = "toggle", default = false },
  })

  -- The options menu sets the resting mode; the hotkey cycles it live for
  -- the session (mod options have no setter), until the menu value changes.
  local lastMode, liveLevel = nil, nil
  -- CAMERA TURN: the hotkey turns it live, until the menu value changes
  local lastYaw, liveYaw = nil, nil

  local function sync()
    local mode = mod.options:get("mode") or "MID"
    if mode ~= lastMode then
      lastMode = mode
      liveLevel = nil
    end
    Bridge.setLevel(liveLevel or LEVELS[mode] or 2)
    local yawOpt = mod.options:get("yaw") or "0"
    if yawOpt ~= lastYaw then lastYaw, liveYaw = yawOpt, nil end
    Bridge.configure({
      heightScale = (tonumber(mod.options:get("height")) or 100) / 100,
      resolution = mod.options:get("resolution") or "auto",
      quality = mod.options:get("quality") or "auto",
      lumps = mod.options:get("relief") ~= false,
      shadows = mod.options:get("shadows") ~= false,
      sunShadows = mod.options:get("sunShadows") ~= false,
      daynight = mod.options:get("daynight") or "game",
      weather3d = mod.options:get("weather3d") ~= false,
      breath = mod.options:get("breath") or "subtle",
      blink = mod.options:get("blink") ~= false,
      nightlights = mod.options:get("nightlights") ~= false,
      reflect = mod.options:get("reflect") ~= false,
      sway = mod.options:get("sway") ~= false,
      critters = mod.options:get("critters") ~= false,
      smoke = mod.options:get("smoke") ~= false,
      footprints = mod.options:get("footprints") ~= false,
      clouds = mod.options:get("clouds") ~= false,
      waves = mod.options:get("waves") ~= false,
      caveFx = mod.options:get("caveFx") ~= false,
      falls = mod.options:get("falls") ~= false,
      wholeMaps = mod.options:get("wholeMaps") ~= false,
      nearMaps = mod.options:get("nearMaps") ~= false,
      prebuild = mod.options:get("prebuild") == true,
      blur = mod.options:get("blur") ~= false,
      roundTrees = mod.options:get("roundTrees") ~= false,
      treeStyle = mod.options:get("treeStyle") or "rounded",
      roofs = mod.options:get("roofs") ~= false,
      solid = tonumber(mod.options:get("solid")) or 3,
      indoorZoom = mod.options:get("indoorZoom") or "fit",
      zoom = (tonumber(mod.options:get("zoom")) or 100) / 100,
      xray = mod.options:get("xray") ~= false,
      rate = mod.options:get("rate") or "auto",
      perf = mod.options:get("perf") == true,
      yaw = liveYaw or tonumber(yawOpt) or 0,
    })
  end

  local HOTKEY = "6"
  local TURN_KEY = "7"
  local TURNS = { 0, 15, 30, -30, -15 }
  local installed, triedAt = false, -1

  local function wantedLevel()
    return liveLevel or LEVELS[mod.options:get("mode") or "OFF"] or 0
  end

  local function install()
    local okLoad, B = pcall(bridge)
    if not okLoad then
      mod.log:warn("Voxel Diorama could not load: %s", tostring(B))
      return false
    end
    local okCall, ok, err = pcall(B.install)
    if not okCall then ok, err = false, ok end
    if not ok then
      mod.log:warn("Voxel Diorama not installed: %s", tostring(err))
      return false
    end
    sync()
    return true
  end

  mod.events:on("game.ready", function()
    if not installed and wantedLevel() > 0 then
      installed = install()
      triedAt = 0
    end
  end)

  -- options can change from the menu at any time; re-read them once a frame
  -- (cheap: a handful of table reads) through the per-step input hook
  mod.hooks:wrap("input.step", function(next, game, dt)
    if not installed then
      if triedAt < 0 and wantedLevel() > 0 then
        triedAt = 0
        installed = install()
      end
      -- still 2D: nothing of the 3D view runs
      if not installed then return next(game, dt) end
    end
    sync()
    -- PRE-BUILD AT START: while its screen is up the player's input is held
    -- (cleared before the game reads it, every step); a fresh press of B
    -- skips it.  (Only a fresh press: B held to run through a door must not.)
    if installed and Bridge.preActive() then
      local inp = game and game.input
      if inp then
        for _, btn in ipairs(inp.pressQueue or {}) do
          if btn == "b" then Bridge.preSkip() break end
        end
        if inp.reset then pcall(inp.reset, inp) end
      end
    end
    return next(game, dt)
  end)

  -- a new session: the next pre-build takes the neighbours along too
  mod.events:on("save.loaded", function() if Bridge then Bridge.newSession() end end)
  mod.events:on("save.created", function() if Bridge then Bridge.newSession() end end)

  mod.hooks:wrap("input.key", function(next, game, ev)
    if ev and ev.phase == "pressed" and ev.key == TURN_KEY and installed and Bridge.level() > 0 then
      local cur = liveYaw or tonumber(mod.options:get("yaw")) or 0
      local i = 1
      for k, v in ipairs(TURNS) do if v == cur then i = k end end
      liveYaw = TURNS[i % #TURNS + 1]
      local name = liveYaw == 0 and "STRAIGHT" or ((liveYaw > 0 and "RIGHT " or "LEFT ") .. math.abs(liveYaw))
      Bridge.toast("CAMERA: " .. name, 2)
      sync()
      return true
    end
    if ev and ev.phase == "pressed" and ev.key == HOTKEY then
      local free = true
      if game and type(game.zoomGateOK) == "function" then
        local ok, res = pcall(game.zoomGateOK, game)
        free = ok and res == true
      end
      if free and not installed then
        triedAt = 0
        installed = install()
        if not installed then return true end
      end
      if free then
        liveLevel = Bridge.cycle()
        local name = ({ "OFF", "LOW", "MID", "HIGH" })[liveLevel + 1]
        mod.log:info("voxel view -> %s", name)
        if liveLevel == 0 then Bridge.toast("VOXEL VIEW: OFF", 2) end
        return true
      end
    end
    return next(game, ev)
  end)

  mod.exports.version = "1.32.1"
  mod.exports.level = function() return (installed and Bridge) and Bridge.level() or 0 end
  -- read-only timings for tools/tests: { capture, render, mesh, avg } in ms
  mod.exports.stats = function()
    if not Bridge then return {} end
    local st = Bridge._state
    return { capture = st.tCapture, render = st.tRender, mesh = st.tMesh,
             avg = st.avgMs, building = st.job ~= nil,
             groundW = st.bigW, groundH = st.bigH, renderW = st.rw, renderH = st.rh,
             verts = st.meshVerts, tris = st.meshTris,
             quality = Bridge.preset().name, half = st.halfNow == true,
             pre = st.pre and { kind = st.pre.kind, done = st.pre.done, total = st.pre.total } or nil,
             preLast = st.preLast }
  end
  -- (wear port addition) why the 3D view is or is not drawing, so the watch
  -- can say it in the middle of the round screen, where it is visible
  mod.exports.status = function()
    if not (installed and Bridge) then return { installed = false, level = 0 } end
    local st = Bridge._state or {}
    return { installed = installed, level = Bridge.level(), why = st.why,
             lastError = st.lastError, disabled = st.disabled == true,
             drawing = st.lastShown ~= nil and st.idleSince == nil }
  end
  mod.exports.setLevel = function(level)
    level = math.floor(tonumber(level) or 0)
    if not installed then
      if level <= 0 then liveLevel = 0 return 0 end
      triedAt = 0
      installed = install()
      if not installed then return 0 end
    end
    liveLevel = Bridge.setLevel(level)
    return liveLevel
  end
end
