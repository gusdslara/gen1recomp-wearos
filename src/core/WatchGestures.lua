-- Wear OS gesture controls: the whole round screen is the controller.
--
--   swipe up/down/left/right        D-pad (a flick = one step / one menu item)
--   swipe and keep the finger down  keep walking; slide the finger anywhere
--                                   to steer, like an analog stick that
--                                   follows the finger (its centre trails a
--                                   short way behind it); a short stroke
--                                   another way turns at once, even straight
--                                   back, without stopping
--   keep dragging far from where    run (holds B for you, overworld only, so
--   the swipe started               it never cancels a menu)
--   tap, by where it lands:
--       top-left / top / top-right  L / SELECT / R
--       middle band right / left    A / B
--       bottom                      START
--   second finger while walking     the button under that finger, held for
--                                   as long as it stays down (the walking
--                                   finger keeps walking)
--   two-finger swipe left / right   L / R
--   three-finger double tap         3D on/off (Voxel Diorama; TILT without it)
--   four-finger tap                 diagnostics overlay on/off
--   bezel / crown (Java side)       menus, battle, text: up/down
--                                   overworld: camera zoom
--   hardware Back (Java side)       START
--
-- Every press is echoed by a short arc on the rim where that button lives,
-- the same visual language as the direction arc, so the screen stays clear.
--
-- Wired in through src/core/TouchControls.lua: every Game class already
-- forwards touches, reset, noteGamepad and draw there, so delegating at that
-- one seam covers Gen 1, Gen 2 and FireRed/LeafGreen without touching them.
-- Buttons go through Input:sourcePress/sourceRelease under "watch:*" sources,
-- the same per-source bookkeeping the touch overlay and mods use, so a held
-- direction merges cleanly with a paired Bluetooth pad.

local Input = require("src.core.Input")
local Watch = require("src.core.Watch")
local WatchText = require("src.core.WatchText")

local WG = {}

local DIR_ANGLE = { right = 0, down = math.pi / 2, left = math.pi, up = -math.pi / 2 }

-- where each button's rim indicator sits (radians, screen y down) and its tint
local BUTTON = {
  a      = { angle = 0,                 label = "A",      color = { 0.40, 0.95, 0.55 } },
  b      = { angle = math.pi,           label = "B",      color = { 1.00, 0.45, 0.40 } },
  start  = { angle = math.pi / 2,       label = "START",  color = { 0.45, 0.72, 1.00 } },
  select = { angle = -math.pi / 2,      label = "SELECT", color = { 0.85, 0.62, 1.00 } },
  l      = { angle = -3 * math.pi / 4,  label = "L",      color = { 1.00, 0.85, 0.35 } },
  r      = { angle = -math.pi / 4,      label = "R",      color = { 1.00, 0.85, 0.35 } },
  tilt   = { angle = -math.pi / 2,      label = "3D",     color = { 1.00, 1.00, 1.00 } },
  flat   = { angle = -math.pi / 2,      label = "2D",     color = { 1.00, 1.00, 1.00 } },
}
local FLASH_TIME = 0.28

local function now()
  return (love and love.timer and love.timer.getTime and love.timer.getTime()) or os.clock()
end

-- centre x, centre y, radius of the visible round face (LOVE units)
local function screen()
  return Watch.face()
end
WG.screen = screen

local function buzz(sec)
  if love and love.system and love.system.vibrate then
    pcall(love.system.vibrate, sec or 0.015)
  end
end

-- Overworld with the player in control: no battle, message, menu, fade or
-- script lock (FRLG's Hud.busy covers bag/party/summary/PC/shop too).  Only
-- then is it safe to hold B for running; anywhere else B would cancel.
local function freeRoam()
  local R = package.loaded["src.core.game3.runtime"]
  local F = package.loaded["src.core.game3.field"]
  if type(R) ~= "table" or type(F) ~= "table" then return false end
  if R.uiBusy then
    local ok, busy = pcall(R.uiBusy)
    if not ok or busy then return false end
  end
  if F.isLocked then
    local ok, locked = pcall(F.isLocked)
    if not ok or locked then return false end
  end
  return true
end
WG.freeRoam = freeRoam

local function dirOf(dx, dy, cur)
  local ax, ay = math.abs(dx), math.abs(dy)
  local bias = 1.25 -- hysteresis: stay on the current axis near the diagonal
  if (cur == "left" or cur == "right") and ax * bias >= ay then
    return dx < 0 and "left" or "right"
  elseif (cur == "up" or cur == "down") and ay * bias >= ax then
    return dy < 0 and "up" or "down"
  end
  if ax >= ay then return dx < 0 and "left" or "right" end
  return dy < 0 and "up" or "down"
end

-- Which button a tap at (x, y) means.  The top cap of the circle is split
-- into L | SELECT | R, the bottom cap is START, and the band in between is
-- B (left) / A (right).
local function tapButton(x, y)
  local cx, cy, R = screen()
  local cfg = Watch.config
  local band = cfg.tapBand * R
  if y <= cy - band then
    local side = (cfg.shoulderX or 0.30) * R
    if x <= cx - side then return "l" end
    if x >= cx + side then return "r" end
    return "select"
  end
  if y >= cy + band then return "start" end
  return (x >= cx) and "a" or "b"
end
WG.tapButton = tapButton

function WG:init(touchControls)
  self.tc = touchControls
  self.touches = {}     -- id -> touch record
  self.primary = nil    -- id of the finger that owns the current gesture
  self.two = nil        -- two-finger gesture record
  self.held = {}        -- "watch:<tag>" -> GB button currently pressed
  self.pending = {}     -- tag -> time to release
  self.dir = nil        -- direction currently held by the swipe finger
  self.dirSince = 0
  self.flashes = {}     -- rim indicators fading out
  self.lastInput = now()
  self.sleepOn = nil
  self.hintUntil = nil
  self.hintShown = false
  self.font = nil
  self.debug = Watch.config.debugOverlay == true
end

---------------------------------------------------------------- buttons --

local function down(self, btn, tag)
  local src = "watch:" .. tag
  if self.held[src] then return end
  self.held[src] = btn
  Input:sourcePress(btn, src)
end

local function up(self, tag)
  local src = "watch:" .. tag
  local btn = self.held[src]
  if not btn then return end
  self.held[src] = nil
  Input:sourceRelease(btn, src)
end

local function flash(self, kind)
  if not BUTTON[kind] then return end
  self.flashes[#self.flashes + 1] = { kind = kind, t = now() }
end

-- press and auto-release after cfg.tapHold (a fresh edge every time)
local function tap(self, btn)
  local tag = "tap:" .. btn
  self.pending[tag] = nil
  up(self, tag)
  down(self, btn, tag)
  self.pending[tag] = now() + Watch.config.tapHold
  flash(self, btn)
  if btn == "start" or btn == "select" or btn == "l" or btn == "r" then buzz(0.015) end
end

local function setDir(self, dir)
  if dir == self.dir and not self.pending.dir then return end
  self.pending.dir = nil
  up(self, "dir")
  self.dir = dir
  if dir then
    down(self, dir, "dir")
    self.dirSince = now()
  end
end

-- finger lifted: keep a just-flicked direction down for minHold so the game
-- registers a whole step (FRLG turns in place on very short presses)
local function endDir(self)
  if not self.dir then return end
  local releaseAt = self.dirSince + Watch.config.minHold
  if now() < releaseAt then
    self.pending.dir = releaseAt
  else
    up(self, "dir")
  end
  self.dir = nil
end

local function hotkey(self, key)
  local handler = self.tc and self.tc.hotkeyHandler
  if not handler then return end
  pcall(handler, "key:" .. key, true)
  pcall(handler, "key:" .. key, false)
end

-- Whether the bundled Voxel Diorama mod (the real 3D view) is running.
WG.VOXEL_MOD = "voxel_world_gen3"
function WG.voxelLoaded(self)
  local game = self and self.tc and self.tc.game
  local status = type(game) == "table" and game.modStatus
  for _, m in ipairs(type(status) == "table" and status.loaded or {}) do
    if type(m) == "table" and m.id == WG.VOXEL_MOD then return true end
  end
  return false
end

-- Why the real 3D is not on screen, or nil when it is (or nothing is wrong).
-- The mod's own warnings are toasts at the top edge of the window, which a
-- round face cuts off, so the watch repeats them in the middle.
local BENIGN = {
  ["mode is OFF"] = true, ["second tilt pass"] = true,
  ["no world pass on this screen"] = true, ["shop"] = true, ["seagallop"] = true,
}
function WG.threeDProblem(self)
  local game = self and self.tc and self.tc.game
  if type(game) ~= "table" then return nil end
  -- the game starts 2D: only a 3D the player asked for can be missing
  if not (self and self.want3D) then return nil end
  local fs = love and love.filesystem
  local bundled = fs and fs.getInfo and fs.getInfo("mods/" .. WG.VOXEL_MOD .. "/manifest.json")
  if not WG.voxelLoaded(self) then
    if not bundled then return nil end
    local status = game.modStatus
    for _, e in ipairs(type(status) == "table" and status.errors or {}) do
      local text = type(e) == "table" and (e.message or e.text or e.error) or e
      if type(text) == "string" and text:find(WG.VOXEL_MOD, 1, true) then
        return "mod: " .. text
      end
    end
    return "mod " .. WG.VOXEL_MOD .. " not loaded"
  end
  local loader = game.mods
  local ex = type(loader) == "table" and type(loader.exports) == "table"
    and loader.exports[WG.VOXEL_MOD]
  if type(ex) ~= "table" or type(ex.status) ~= "function" then return nil end
  local ok, st = pcall(ex.status)
  if not ok or type(st) ~= "table" then return nil end
  if st.disabled or st.lastError then return tostring(st.lastError or "stopped") end
  if not st.installed then return "could not start" end
  if (st.level or 0) > 0 and not st.drawing and st.why and not BENIGN[st.why] then
    return tostring(st.why)
  end
  return nil
end

local function voxelExports(self)
  local game = self and self.tc and self.tc.game
  local loader = type(game) == "table" and game.mods
  local ex = type(loader) == "table" and type(loader.exports) == "table"
    and loader.exports[WG.VOXEL_MOD]
  return type(ex) == "table" and ex or nil
end

-- 2D <-> 3D.  With the Voxel Diorama mod: OFF <-> Watch.config.voxelLevel
-- (the mod loads its 3D code the first time this turns it on).  Without it:
-- the engine's TILT, OFF <-> 35 degrees.
function WG.toggle3D(self)
  local ex = WG.voxelLoaded(self) and voxelExports(self)
  local on
  if ex and type(ex.setLevel) == "function" then
    local cur = 0
    if type(ex.level) == "function" then
      local okL, lv = pcall(ex.level)
      cur = okL and tonumber(lv) or 0
    end
    local want = cur > 0 and 0 or (Watch.config.voxelLevel or 2)
    local okS, got = pcall(ex.setLevel, want)
    on = okS and (tonumber(got) or 0) > 0
    if want > 0 and not on then on = false end
    self.want3D = want > 0
  else
    local Tilt = require("src.render.Tilt")
    on = not (Tilt.level and Tilt.level > 0)
    Tilt.setLevel(on and 2 or 0)
    self.want3D = false
  end
  self.loading3D = (on and ex) and now() or nil
  self.lastProblem, self.problemUntil = nil, nil
  flash(self, on and "tilt" or "flat")
  buzz(0.03)
  return on
end

local function noteActivity(self)
  self.lastInput = now()
  if self.hintUntil then self.hintUntil = nil end
end

------------------------------------------------------------------ tick --

function WG:tick()
  local t = now()
  local cfg = Watch.config
  local _, _, R = screen()
  local p = self.primary and self.touches[self.primary]

  -- scheduled releases
  for tag, at in pairs(self.pending) do
    if t >= at then
      self.pending[tag] = nil
      up(self, tag)
    end
  end

  -- running: hold B while a direction is held far from the anchor (or always,
  -- with alwaysRun), only in free roam so menus never see it
  local wantRun = false
  if self.dir and p and p.kind == "dir" and t - self.dirSince >= cfg.runDelay then
    -- how far the finger has gone from where the swipe began (the stick's
    -- own centre trails close behind, so that is not the measure)
    local tx, ty = (p.x or 0) - (p.sx or p.x or 0), (p.y or 0) - (p.sy or p.y or 0)
    local far = math.sqrt(tx * tx + ty * ty) >= cfg.runRadius * R
    if (far or cfg.alwaysRun) and freeRoam() then wantRun = true end
  end
  if wantRun then
    down(self, "b", "run")
  elseif self.held["watch:run"] then
    up(self, "run")
  end
  self.running = wantRun

  -- let the watch sleep after a while without input (and keep it awake while
  -- playing); the activity then pauses and LOVE stops rendering entirely
  local sleepy = (t - self.lastInput) >= cfg.idleSleep
  if sleepy ~= self.sleepOn and love and love.window and love.window.setDisplaySleepEnabled then
    pcall(love.window.setDisplaySleepEnabled, sleepy)
    self.sleepOn = sleepy
  end
end

--------------------------------------------------------------- touches --

local function count(tbl)
  local n = 0
  for _ in pairs(tbl) do n = n + 1 end
  return n
end

function WG:touchpressed(id, x, y)
  noteActivity(self)
  local t = now()
  local p = self.primary and self.touches[self.primary]

  -- third / fourth finger landing on a fresh two-finger touch: a three-
  -- finger tap (3D, when doubled) or a four-finger tap (diagnostics)
  if self.two and (not self.two.done or self.two.fingers)
      and t - self.two.t0 < Watch.config.twoFingerWindow * 2 then
    self.two.done = true
    self.two.fingers = (self.two.fingers or 2) + 1
    self.touches[id] = { kind = "ignored" }
    self:tick()
    return true
  end

  if not p then
    self.touches[id] = { x0 = x, y0 = y, x = x, y = y, t0 = t, kind = "pending", dist = 0,
                         sx = x, sy = y }
    self.primary = id
  elseif p.kind == "pending" and not self.two and t - p.t0 < Watch.config.twoFingerWindow then
    -- second finger right after the first: a two-finger gesture
    p.kind = "two"
    self.touches[id] = { x0 = x, y0 = y, x = x, y = y, t0 = t, kind = "two" }
    self.two = { cx0 = (p.x + x) / 2, cy0 = (p.y + y) / 2, t0 = t, done = false }
    self.two.cx, self.two.cy = self.two.cx0, self.two.cy0
  elseif p.kind ~= "two" then
    -- another finger while the first one walks / waits:
    -- only register as aux button if primary is actually walking ('dir')
    -- and the second touch is away from the screen center, preventing accidental
    -- B (cancel) or A presses when the thumb slides or touches the screen during swipe
    local _, _, R = screen()
    local cx, cy = screen()
    local distCenter = math.sqrt((x - cx) * (x - cx) + (y - cy) * (y - cy))
    if p.kind == "dir" and distCenter > 0.45 * R then
      local btn = tapButton(x, y)
      local tag = "aux:" .. tostring(id)
      self.touches[id] = { kind = "aux", btn = btn, tag = tag, t0 = t }
      self.pending[tag] = nil
      down(self, btn, tag)
      flash(self, btn)
      if btn ~= "a" and btn ~= "b" then buzz(0.015) end
    else
      self.touches[id] = { kind = "ignored" }
    end
  else
    self.touches[id] = { kind = "ignored" }
  end
  self:tick()
  return true
end

function WG:touchmoved(id, x, y)
  local tch = self.touches[id]
  if not tch or tch.kind == "ignored" or tch.kind == "aux" then return end
  noteActivity(self)
  tch.x, tch.y = x, y
  local cfg = Watch.config
  local _, _, R = screen()

  if tch.kind == "two" and self.two then
    local sx, sy, k = 0, 0, 0
    for _, o in pairs(self.touches) do
      if o.kind == "two" then sx, sy, k = sx + o.x, sy + o.y, k + 1 end
    end
    if k > 0 then self.two.cx, self.two.cy = sx / k, sy / k end
    return
  end

  if tch.kind == "pending" or tch.kind == "dir" then
    local swipePx = cfg.swipe * R
    -- Steering by the finger's own motion.  The stick's centre only trails
    -- a finger that pulls away from it, so on its own, sliding back the way
    -- you came first crossed the centre (standing still there) and only
    -- turned after the whole trail length plus a swipe -- the player saw the
    -- character stop.  A short, clear stroke in another direction now
    -- re-centres the stick just behind the finger: it turns at once.
    if tch.kind == "dir" and self.dir then
      local px, py = tch.px or x, tch.py or y
      local mx, my = x - px, y - py
      local m = math.sqrt(mx * mx + my * my)
      local turnPx = (cfg.turn or 0.06) * R
      if m >= turnPx then
        local ax, ay = math.abs(mx), math.abs(my)
        local mdir = dirOf(mx, my, nil)
        if mdir ~= self.dir and math.max(ax, ay) >= 1.5 * math.min(ax, ay) then
          local k = swipePx * 1.2 / m
          tch.x0, tch.y0 = x - mx * k, y - my * k
          -- running is measured from here on, in the new direction
          tch.sx, tch.sy = tch.x0, tch.y0
          tch.px, tch.py = x, y
        elseif m > turnPx * 2 then
          -- the stroke's start keeps a short way behind the finger, so the
          -- next turn is measured from the latest motion
          tch.px, tch.py = x - mx / m * turnPx, y - my / m * turnPx
        end
      end
    end
    local dx, dy = x - tch.x0, y - tch.y0
    local dist = math.sqrt(dx * dx + dy * dy)
    -- joystick anchor follows a finger that goes past joystickMax, so turning
    -- around never needs a long drag back across the screen
    local maxPx = cfg.joystickMax * R
    if dist > maxPx then
      tch.x0 = x - dx / dist * maxPx
      tch.y0 = y - dy / dist * maxPx
      dx, dy, dist = x - tch.x0, y - tch.y0, maxPx
    end
    tch.dist = dist
    if tch.kind == "pending" then
      if dist >= swipePx then
        tch.kind = "dir"
        tch.px, tch.py = x, y
        setDir(self, dirOf(dx, dy, nil))
      end
    else
      if dist < swipePx * 0.5 then
        -- back on the anchor: stand still, finger still down
        if self.dir then setDir(self, nil) end
      elseif dist >= swipePx * 0.8 or self.dir then
        setDir(self, dirOf(dx, dy, self.dir))
      end
    end
  end
  self:tick()
end

function WG:touchreleased(id, x, y)
  local tch = self.touches[id]
  if not tch then return end
  self.touches[id] = nil
  self.lastTouchEnd = now()
  noteActivity(self)
  local cfg = Watch.config
  local _, _, R = screen()

  if tch.kind == "aux" then
    -- keep even a very quick tap down long enough to register
    local releaseAt = tch.t0 + cfg.tapHold
    if now() < releaseAt then
      self.pending[tch.tag] = releaseAt
    else
      up(self, tch.tag)
    end
    self:tick()
    return
  end

  if tch.kind == "two" and self.two then
    local two = self.two
    if not two.done then
      two.done = true
      local dx, dy = two.cx - two.cx0, two.cy - two.cy0
      local swipePx = cfg.swipe * R
      if math.abs(dx) >= swipePx and math.abs(dx) > math.abs(dy) then
        tap(self, dx < 0 and "l" or "r")
        self.twoTapCount = 0
        self.lastTwoTap = nil
      else
        local quick = now() - two.t0 < 0.45
        local still = math.abs(dx) < swipePx and math.abs(dy) < swipePx
        if quick and still and not two.fingers then
          local tt = now()
          local gap = cfg.twoTapGap or 0.6
          if self.lastTwoTap and tt - self.lastTwoTap < gap then
            self.twoTapCount = (self.twoTapCount or 1) + 1
          else
            self.twoTapCount = 1
          end
          self.lastTwoTap = tt

          if self.twoTapCount >= 3 then
            self.twoTapCount = 0
            self.lastTwoTap = nil
            WG.toggle3D(self)
          end
        end
      end
    end
    -- the first two fingers of a three / four finger tap lifting: decide once
    if two.fingers and not two.decided then
      two.decided = true
      local quick = now() - two.t0 < 0.6
      local dx, dy = two.cx - two.cx0, two.cy - two.cy0
      local still = math.abs(dx) < cfg.swipe * R and math.abs(dy) < cfg.swipe * R
      if quick and still and two.fingers >= 4 then
        self.debug = not self.debug
        self.lastThreeTap = nil
      elseif quick and still and two.fingers == 3 then
        local tt = now()
        if self.lastThreeTap and tt - self.lastThreeTap < cfg.threeTapGap then
          self.lastThreeTap = nil
          WG.toggle3D(self)
        else
          self.lastThreeTap = tt
        end
      end
    end
    local left = false
    for _, o in pairs(self.touches) do
      if o.kind == "two" then left = true end
    end
    if not left then self.two = nil end
    if id == self.primary then self.primary = nil end
    self:tick()
    return
  end

  if id == self.primary then
    self.primary = nil
    if tch.kind == "pending" then
      -- a finger that never travelled far enough to be a swipe is a tap,
      -- however long it stayed down
      tap(self, tapButton(tch.x0, tch.y0))
    elseif tch.kind == "dir" then
      endDir(self)
      up(self, "run")
    end
  end
  self:tick()
end

-- OS stole the touch / focus lost: drop everything we hold.
function WG:reset()
  for src in pairs(self.held or {}) do
    up(self, src:sub(7)) -- strip "watch:"
  end
  self.held, self.pending = {}, {}
  self.touches, self.primary, self.two = {}, nil, nil
  self.dir = nil
  self.running = false
end

-- Bezel / crown arrive as mouse-wheel steps (the Java side converts rotary
-- events).  Returns handled, y-for-the-game.  In free roam the wheel keeps its
-- normal job (camera zoom), flipped so clockwise zooms in; elsewhere it
-- scrolls menus, lists, move selection and the PC.
function WG:wheelmoved(x, y)
  if not Watch.active() then return false, y end
  if type(y) ~= "number" or y == 0 then return false, y end
  -- A finger on the glass (or just lifted): this "rotation" is Wear OS's
  -- touch-bezel turning a curved drag along the rim into crown steps, i.e.
  -- the player walking in an arc.  Swallow it; it zoomed the map in and out.
  if next(self.touches or {}) ~= nil
      or now() - (self.lastTouchEnd or -math.huge) < Watch.config.wheelTouchGuard then
    return true, 0
  end
  noteActivity(self)
  if freeRoam() then
    return false, -y
  end
  local btn = y > 0 and "up" or "down"
  local tag = "tap:" .. btn
  self.pending[tag] = nil
  up(self, tag)
  down(self, btn, tag)
  self.pending[tag] = now() + Watch.config.tapHold
  return true, y
end

------------------------------------------------------------------ draw --

local function hintLines()
  return WatchText.hintLines()
end

-- the pixel font, sized from the face (real pixels: R is in LOVE units)
local function getFont(self, G, R)
  if not self.font or self.fontR ~= R then
    local dpi = (G.getDPIScale and G.getDPIScale()) or 1
    self.font = WatchText.font(11 * math.max(1, math.floor(R * dpi / 170 + 0.5)))
    self.fontR = R
  end
  return self.font
end

-- one rim indicator: a short arc in the button's colour plus its label just
-- inside the rim
local function drawButtonArc(self, G, cx, cy, R, kind, alpha)
  local b = BUTTON[kind]
  if not b then return end
  local lw = math.max(3, R * 0.03)
  local half = (#b.label > 1) and 0.30 or 0.20
  local c = b.color
  G.setColor(c[1], c[2], c[3], 0.85 * alpha)
  G.setLineWidth(lw)
  G.arc("line", "open", cx, cy, R - lw, b.angle - half, b.angle + half, 16)
  local font = getFont(self, G, R)
  G.setFont(font)
  local lx = cx + math.cos(b.angle) * (R - lw * 2 - font:getHeight() * 0.9)
  local ly = cy + math.sin(b.angle) * (R - lw * 2 - font:getHeight() * 0.9)
  local tw = font:getWidth(b.label)
  G.setColor(0, 0, 0, 0.45 * alpha)
  G.print(b.label, math.floor(lx - tw / 2 + 1), math.floor(ly - font:getHeight() / 2 + 1))
  G.setColor(c[1], c[2], c[3], alpha)
  G.print(b.label, math.floor(lx - tw / 2), math.floor(ly - font:getHeight() / 2))
end

local function debugLines()
  local G = love.graphics
  local ww, wh = G.getDimensions()
  local pw, ph = ww, wh
  if G.getPixelDimensions then pw, ph = G.getPixelDimensions() end
  local dw, dh = "?", "?"
  if love.window and love.window.getDesktopDimensions then
    local ok, a, b = pcall(love.window.getDesktopDimensions)
    if ok then dw, dh = a, b end
  end
  local sx, sy, sw, sh = "?", "?", "?", "?"
  if love.window and love.window.getSafeArea then
    local ok, a, b, c, d = pcall(love.window.getSafeArea)
    if ok then sx, sy, sw, sh = a, b, c, d end
  end
  local fx, fy, fw = Watch.screenRect()
  local hv = Watch.hostViewport()
  local fmt = function(v) return type(v) == "number" and ("%.0f"):format(v) or tostring(v) end
  return {
    "win " .. fmt(ww) .. "x" .. fmt(wh) .. "  px " .. fmt(pw) .. "x" .. fmt(ph),
    "dpi " .. ("%.2f"):format(G.getDPIScale and G.getDPIScale() or 1),
    "desk " .. fmt(dw) .. "x" .. fmt(dh),
    "safe " .. fmt(sx) .. "," .. fmt(sy) .. " " .. fmt(sw) .. "x" .. fmt(sh),
    "face " .. fmt(fx) .. "," .. fmt(fy) .. " " .. fmt(fw),
    "host " .. (hv and (fmt(hv.sx) .. "," .. fmt(hv.sy) .. " " .. fmt(hv.sw) .. "x" .. fmt(hv.sh)
      .. " disp " .. fmt(hv.dw) .. "x" .. fmt(hv.dh)) or "-"),
    "3D " .. (WG.voxelLoaded(WG) and "voxel" or "tilt") .. ": "
      .. tostring(select(2, pcall(WG.threeDProblem, WG)) or "ok"),
  }
end

function WG:draw()
  self:tick()
  local G = love and love.graphics
  if not G then return end
  local t = now()
  local cfg = Watch.config
  local cx, cy, R = screen()

  if not self.hintShown then
    self.hintShown = true
    self.hintUntil = t + cfg.hintSeconds
    -- the screen metrics once in logcat (adb logcat | findstr "[watch]")
    pcall(function() print("[watch] " .. table.concat(debugLines(), " | ")) end)
  end

  -- real-3D problems, shown once each in the middle of the face
  if t >= (self.nextProblemCheck or 0) then
    self.nextProblemCheck = t + 1
    self.gameSince = self.gameSince or t
    if t - self.gameSince > 6 and freeRoam() then
      local okP, problem = pcall(WG.threeDProblem, self)
      if okP and problem and problem ~= self.lastProblem then
        self.lastProblem = problem
        self.problemUntil = t + 10
      end
    end
  end
  local problem = self.problemUntil and t < self.problemUntil and self.lastProblem

  -- 3D switched on but its first picture not up yet: a loading ring
  local loading = false
  if self.loading3D then
    local ex = voxelExports(self)
    local okS, st = false, nil
    if ex and type(ex.status) == "function" then okS, st = pcall(ex.status) end
    if (okS and type(st) == "table" and (st.drawing or st.lastError or (st.level or 0) == 0))
        or t - self.loading3D > 25 then
      self.loading3D = nil
    else
      loading = true
      problem = nil
    end
  end

  -- held buttons (second finger, run) keep their arc lit
  local heldKinds = {}
  for _, tch in pairs(self.touches) do
    if tch.kind == "aux" then heldKinds[tch.btn] = true end
  end
  if self.running then heldKinds.b = true end

  local hasFlash = #self.flashes > 0
  local hint = self.hintUntil and t < self.hintUntil
  if not (self.dir or hasFlash or hint or next(heldKinds) or self.debug or problem or loading) then return end

  G.push("all")
  G.origin()

  if self.dir then
    local a = DIR_ANGLE[self.dir]
    if self.running then G.setColor(1, 0.6, 0.15, 0.85) else G.setColor(1, 1, 1, 0.55) end
    G.setLineWidth(math.max(3, R * 0.03))
    G.arc("line", "open", cx, cy, R - math.max(3, R * 0.03), a - 0.38, a + 0.38, 16)
  end

  for kind in pairs(heldKinds) do
    drawButtonArc(self, G, cx, cy, R, kind, 1)
  end

  if hasFlash then
    local keep = {}
    for _, f in ipairs(self.flashes) do
      local age = t - f.t
      if age < FLASH_TIME then
        if not heldKinds[f.kind] then
          drawButtonArc(self, G, cx, cy, R, f.kind, 1 - age / FLASH_TIME)
        end
        keep[#keep + 1] = f
      end
    end
    self.flashes = keep
  end

  if hint then
    local lines = hintLines()
    if not self.hintFont or self.hintFontR ~= R or self.hintLinesRef ~= lines then
      -- every line fits the circle's width at its own height (the top and
      -- bottom lines get the narrow chords), keeping off the very rim
      local dpi = (G.getDPIScale and G.getDPIScale()) or 1
      self.hintFont, self.hintYs = WatchText.fitCircle(lines, R * 0.94, R * dpi * 0.16)
      self.hintFontR = R
      self.hintLinesRef = lines
    end
    local font = self.hintFont
    G.setColor(0, 0, 0, 0.78)
    G.circle("fill", cx, cy, R, 48)
    G.setFont(font)
    for i, line in ipairs(lines) do
      if i == 1 then G.setColor(1, 0.8, 0.3, 1) else G.setColor(1, 1, 1, 1) end
      local w = font:getWidth(line)
      G.print(line, math.floor(cx - w / 2), math.floor(cy + self.hintYs[i]))
    end
  end

  if loading then
    local font = getFont(self, G, R)
    G.setFont(font)
    local a = t * 5
    G.setLineWidth(math.max(3, R * 0.03))
    G.setColor(0, 0, 0, 0.6)
    G.circle("fill", cx, cy, R * 0.32, 40)
    G.setColor(1, 1, 1, 0.9)
    G.arc("line", "open", cx, cy, R * 0.26, a, a + 1.6, 20)
    local text = WatchText.t("loading3d")
    G.printf(text, cx - R * 0.6, cy - font:getHeight() / 2, R * 1.2, "center")
  end

  if problem and not hint then
    local font = getFont(self, G, R)
    G.setFont(font)
    local text = "3D: " .. problem
    local maxW = R * 1.4
    local _, wrapped = font:getWrap(text, maxW)
    local lh = font:getHeight() * 1.1
    local h = lh * #wrapped + 6
    G.setColor(0, 0, 0, 0.75)
    G.rectangle("fill", cx - maxW / 2 - 4, cy - h / 2, maxW + 8, h, 4, 4)
    G.setColor(1, 0.8, 0.3, 1)
    G.printf(text, cx - maxW / 2, cy - h / 2 + 3, maxW, "center")
  end

  if self.debug then
    local font = getFont(self, G, R)
    G.setFont(font)
    -- crosshair on the face centre the game uses, and the face outline
    G.setLineWidth(1)
    G.setColor(1, 0.2, 0.9, 0.9)
    G.line(cx - 10, cy, cx + 10, cy)
    G.line(cx, cy - 10, cx, cy + 10)
    G.circle("line", cx, cy, R - 1, 64)
    local lines = debugLines()
    local lh = font:getHeight() * 1.1
    local y = cy - lh * #lines / 2
    for _, line in ipairs(lines) do
      local w = font:getWidth(line)
      G.setColor(0, 0, 0, 0.7)
      G.rectangle("fill", cx - w / 2 - 2, y, w + 4, lh)
      G.setColor(1, 1, 1, 1)
      G.print(line, math.floor(cx - w / 2), math.floor(y))
      y = y + lh
    end
  end

  G.pop()
end

return WG
