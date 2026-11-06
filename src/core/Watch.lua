-- Wear OS (smartwatch) mode: detection, tunables and round-screen fitting.
--
-- Active when the packaged game.love carries a `wearos.flag` file at its
-- root (the :wear Gradle module adds it; phone builds never do), or when
-- POKEPORT_WATCH=1 forces it on for desktop testing.  POKEPORT_WATCH=0
-- forces it off everywhere.
--
-- Everything watch-specific in the Lua side hangs off this module:
--   * src/core/WatchGestures.lua  -- swipe / tap / long-press controls
--   * src/render/Renderer.lua     -- world scale + round-safe UI scale
--   * src/core/game3/display.lua  -- the same UI fit for the FRLG flat path
--   * src/core/Performance.lua    -- "watch" tier (30 FPS, no survey/shader)
-- Zero requires, so Performance can consult it while conf.lua is loading.

local Watch = {}

Watch.config = {
  -- Gestures (fractions of the screen radius / seconds)
  swipe = 0.12,        -- finger travel that turns a touch into a swipe
  runRadius = 0.45,    -- drag at least this far from where the swipe began = run
  joystickMax = 0.25,  -- analog stick: its centre trails the finger by at most
                       -- this much, so steering follows the finger anywhere
  turn = 0.06,         -- a stroke this long in another direction turns the
                       -- walk at once (even straight back), wherever the
                       -- stick's centre is
  tapBand = 0.45,      -- taps farther than this (fraction of the radius)
                       -- above the centre = SELECT, below = START; the band
                       -- in between is B (left half) / A (right half)
  minHold = 0.14,      -- a quick flick still holds the direction this long,
                       -- enough for FRLG to take a full step instead of a turn
  shoulderX = 0.30,    -- in the top cap, taps farther than this from the
                       -- vertical centre line are L (left) / R (right)
  tapHold = 0.06,      -- how long a tap keeps A/B/START/SELECT down
  -- two-finger gestures must start within this long of each other
  twoFingerWindow = 0.35,
  wheelTouchGuard = 0.4, -- crown/bezel steps are ignored while a finger is
                         -- down; steps this soon after a walking finger
                         -- lifts mean Galaxy's touch bezel took the drag
                         -- over, and the walk goes on instead of zooming
  bezelWalkEnd = 0.35, -- that carried-on walk stops this long after the
                       -- last bezel step (the finger left the rim)
  spinSteps = 2,       -- map zoom starts on this many bezel/crown steps in
                       -- one sense, a stray single step never zooms
  spinGap = 0.4,       -- max seconds between the steps of one spin
  twoTapGap = 0.6,     -- max seconds between two-finger taps
  threeTapGap = 0.6,   -- max seconds between the two three-finger taps (3D)
  voxelLevel = 2,      -- 3D camera when switched on: 1 LOW, 2 MID, 3 HIGH
  runDelay = 0.20,     -- direction must be held this long before running
  alwaysRun = false,   -- true = hold B whenever walking in the overworld
  -- Display
  fit = "circle",      -- "circle": UI inscribed in the round screen (fractional)
                       -- "integer": original whole-pixel letterbox
  circleMargin = 1.05, -- >1 lets the UI corners (just window borders) clip a bit
  clampToDisplay = true, -- treat only the real display as the screen (see
                         -- Watch.screenRect)
  worldView = 200,     -- GBA pixels visible across the round screen in the map
  fill = "ambient",    -- full-screen 240x160 screens (intro, menus, battle):
                       -- "ambient" fills the round edge around the sharp
                       -- picture with a blurred, dimmed extension of it;
                       -- "black" leaves the plain bars
  ambientDim = 0.55,   -- brightness of that blurred edge (0..1)
  -- Power
  fps = 30,            -- render cap for the "watch" performance tier
  idleSleep = 60,      -- seconds without input before the watch may sleep
  hintSeconds = 7,     -- controls cheat-sheet on the first game frame
  language = "auto",   -- watch screens + translation mod: "auto" follows the
                       -- device; or "pt", "es", "en", "fr", "de", "ru"
  debugOverlay = false,-- start with the screen-metrics overlay on (a
                       -- three-finger tap toggles it any time)
}

local cached

-- The visible round face, in LOVE units: x, y, w, h of the centred square
-- the game should treat as "the screen".  Normally the whole window, but on
-- some Wear OS builds (seen on the API 37 emulator) the app window comes out
-- wider than the 384x384 display -- ~480x384, anchored top-left -- so the
-- window centre is not the watch centre and everything drew ~46 px to the
-- right, with its right edge off the glass.  SDL's desktop size is the real
-- display, so the window is clamped to it before taking the square.
-- The Android host (WearGameActivity) writes where the game surface sits on
-- the physical display: "surfaceX,surfaceY,surfaceW,surfaceH,displayW,
-- displayH" in pixels.  Re-read at most once a second (layout can change).
local hostCache, hostReadAt = nil, -math.huge
local function hostViewport()
  local path = os.getenv("POKEPORT_VIEWPORT_FILE")
  if not path or path == "" then return nil end
  local t = (love and love.timer and love.timer.getTime and love.timer.getTime()) or 0
  if t - hostReadAt < 1 then return hostCache end
  hostReadAt = t
  local f = io.open(path, "rb")
  if not f then return hostCache end
  local line = f:read("*l")
  f:close()
  local n = {}
  for v in tostring(line or ""):gmatch("%-?%d+") do n[#n + 1] = tonumber(v) end
  if #n >= 6 and n[3] > 0 and n[4] > 0 and n[5] > 0 and n[6] > 0 then
    hostCache = { sx = n[1], sy = n[2], sw = n[3], sh = n[4], dw = n[5], dh = n[6] }
  end
  return hostCache
end
Watch.hostViewport = hostViewport

function Watch.screenRect(ww, wh)
  local G = love and love.graphics
  if not (ww and wh) and G and G.getDimensions then ww, wh = G.getDimensions() end
  ww, wh = tonumber(ww) or 1, tonumber(wh) or 1
  local w, h = ww, wh
  local win = love and love.window
  -- exact: the part of the surface the display really shows
  local host = Watch.config.clampToDisplay and hostViewport()
  if host then
    local pw, ph = ww, wh
    if G and G.getPixelDimensions then pw, ph = G.getPixelDimensions() end
    local kx, ky = ww / math.max(1, pw), wh / math.max(1, ph) -- px -> units
    local x0 = math.max(0, -host.sx)
    local y0 = math.max(0, -host.sy)
    local x1 = math.min(host.sw, host.dw - host.sx)
    local y1 = math.min(host.sh, host.dh - host.sy)
    if x1 > x0 and y1 > y0 then
      local rx, ry, rw, rh = x0 * kx, y0 * ky, (x1 - x0) * kx, (y1 - y0) * ky
      local s = math.min(rw, rh)
      return rx + (rw - s) / 2, ry + (rh - s) / 2, s, s
    end
  end
  if Watch.config.clampToDisplay and win and win.getDesktopDimensions then
    local ok, dw, dh = pcall(win.getDesktopDimensions)
    if ok and tonumber(dw) and tonumber(dh) and dw > 0 and dh > 0 then
      -- SDL may answer in pixels or in units; anything wider than the window
      -- is taken as pixels and brought back to units
      local dpi = (G and G.getDPIScale and tonumber(G.getDPIScale())) or 1
      if dpi <= 0 then dpi = 1 end
      if dw > ww + 0.5 then dw = dw / dpi end
      if dh > wh + 0.5 then dh = dh / dpi end
      w, h = math.min(ww, dw), math.min(wh, dh)
    end
  end
  local s = math.min(w, h)
  return (w - s) / 2, (h - s) / 2, s, s
end

-- Centre and radius of the face, in LOVE units.
function Watch.face()
  local x, y, w = Watch.screenRect()
  return x + w / 2, y + w / 2, math.max(1, w / 2)
end

function Watch.active()
  if cached ~= nil then return cached end
  local env = os.getenv("POKEPORT_WATCH")
  if env == "1" then
    cached = true
  elseif env == "0" then
    cached = false
  else
    local fs = love and love.filesystem
    local ok, info = false, nil
    if fs and fs.getInfo then ok, info = pcall(fs.getInfo, "wearos.flag") end
    cached = (ok and info ~= nil) or false
  end
  return cached
end

-- Tests / desktop harness can flip the mode at runtime.
function Watch._setActiveForTests(v)
  cached = v
end

-- Integer world pixels-per-GBA-pixel for the overworld on a round screen of
-- pw x ph physical pixels.  Chosen so roughly `worldView` GBA pixels span the
-- diameter: 2x on 384..480 px watches, the classic 15x10-tile feel through a
-- round window.  Whole numbers keep the tile art crisp.
function Watch.worldScale(pw, ph)
  local d = math.min(tonumber(pw) or 0, tonumber(ph) or 0)
  if d <= 0 then return 1 end
  return math.max(1, math.floor(d / Watch.config.worldView + 0.5))
end

-- Physical pixels per UI pixel for a uiw x uih surface (240x160 on FRLG,
-- 160x144 on Gen 1/2) shown on a round pw x ph display.  "circle" inscribes
-- the rectangle in the circle (corners on the rim, times circleMargin), so
-- text boxes and the START menu never fall off the round edge.  Fractional
-- by nature; snapped so the blit is a whole number of physical pixels wide.
function Watch.uiScale(pw, ph, uiw, uih, fallback)
  if Watch.config.fit ~= "circle" then return fallback end
  pw, ph, uiw, uih = tonumber(pw), tonumber(ph), tonumber(uiw), tonumber(uih)
  if not (pw and ph and uiw and uih) or uiw <= 0 or uih <= 0 then
    return fallback
  end
  local r = math.min(pw, ph) / 2
  local halfDiag = math.sqrt((uiw / 2) ^ 2 + (uih / 2) ^ 2)
  local k = r / halfDiag * Watch.config.circleMargin
  k = math.min(k, pw / uiw, ph / uih)
  k = math.floor(k * uiw) / uiw
  if k <= 0 then return fallback end
  return k
end

return Watch
