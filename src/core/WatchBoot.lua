-- Wear OS boot: open like a native game, never through the desktop launcher.
--
-- When the private game data has not been generated yet:
--   * development builds (`gradlew :wear:assembleDebug`) carry the ROM inside
--     game.love under devrom/ (any .gba in mobile/android/wear/dev-rom/) and
--     import it straight away;
--   * otherwise a round "send the ROM" screen waits for it, and the ROM can
--     arrive three ways, all picked up on their own:
--       - over Wi-Fi: the watch shows a URL and its QR code; a phone or PC on
--         the same network (or a phone sharing its hotspot) opens it, picks
--         the .gba and sends it;
--       - from anywhere in the watch's storage (Download/, ...), once "All
--         files access" is allowed (a tap on the screen opens that setting);
--       - adb push into the save folder.
--     The Wi-Fi server and the storage search are Android code
--     (mobile/android/wear/src/main/java/.../RomInbox.java); this side tells
--     it when a ROM is wanted and draws what it reports (inbox files below).
--     A ROM that lands in the save folder is imported; the copy is deleted
--     after a successful import.
-- Either way a round progress screen runs during the import and the game
-- boots as soon as it finishes; later launches go straight into the game.
-- Closing the game on the watch exits the app (main.lua / WearGameActivity).

local Watch = require("src.core.Watch")
local WatchText = require("src.core.WatchText")

local WatchBoot = {}

WatchBoot.BUNDLED_DIR = "devrom"
WatchBoot.POLL_SECONDS = 1.5
WatchBoot.INBOX_SECONDS = 0.4
local ROM_BYTES = 16 * 1024 * 1024

function WatchBoot.bundledRom()
  local fs = love and love.filesystem
  if not (fs and fs.getDirectoryItems and fs.getInfo) then return nil end
  local okInfo, info = pcall(fs.getInfo, WatchBoot.BUNDLED_DIR, "directory")
  if not okInfo or not info then return nil end
  local okList, items = pcall(fs.getDirectoryItems, WatchBoot.BUNDLED_DIR)
  if not okList or type(items) ~= "table" then return nil end
  table.sort(items)
  for _, name in ipairs(items) do
    if name:lower():match("%.gba$") then
      return WatchBoot.BUNDLED_DIR .. "/" .. name
    end
  end
  return nil
end

-- A .gba of the right size sitting at the save-directory root that has not
-- been tried in its current state.  Only names and sizes are looked at here;
-- the importer reads and verifies (SHA-1) the one returned.
local function pendingSaveDirRom(imp)
  local fs = love.filesystem
  local okList, items = pcall(fs.getDirectoryItems, "")
  if not okList or type(items) ~= "table" then return nil end
  table.sort(items)
  imp._watchTried = imp._watchTried or {}
  for _, name in ipairs(items) do
    if name:lower():match("%.gba$") then
      local okInfo, info = pcall(fs.getInfo, name, "file")
      if okInfo and info and info.size == ROM_BYTES then
        local key = name .. ":" .. tostring(info.modtime)
        if not imp._watchTried[key] then
          imp._watchTried[key] = true
          return name
        end
      end
    end
  end
  return nil
end

local function swallow() end

local function startFromSaveDir(imp)
  local name = pendingSaveDirRom(imp)
  if not name then return false end
  local ok, data = pcall(love.filesystem.read, name)
  if not ok or type(data) ~= "string" then return false end
  print("[watch] importing ROM from the save folder: " .. name)
  -- bare name: the importer deletes this copy once the import succeeds
  imp:startData(data, name)
  return true
end

------------------------------------------------------------------ inbox --
-- Two small files in the app's external files folder (POKEPORT_ROM_INBOX,
-- set by WearGameActivity): rom_inbox_ctl.txt is written here, and
-- rom_inbox_status.txt by RomInbox.java ("key=value" lines: state, wifi,
-- url, qrsize, qr, progress, msg, perm).

local inbox = { status = nil, ctl = nil, perm = 0, done = false }
WatchBoot.inbox = inbox

local function inboxDir()
  local dir = os.getenv("POKEPORT_ROM_INBOX")
  if dir and dir ~= "" then return dir end
  return nil
end

local function writeFile(path, text)
  local f = io.open(path .. ".tmp", "wb")
  if not f then return false end
  f:write(text)
  f:close()
  if not os.rename(path .. ".tmp", path) then
    os.remove(path)
    os.rename(path .. ".tmp", path)
  end
  return true
end

-- want: a ROM is needed now (not while one imports); done: the game booted.
local function writeCtl(imp)
  local dir = inboxDir()
  if not dir then return end
  local state = imp and imp.workState
  local want = not inbox.done and state ~= "working" and state ~= "complete"
  local save = (love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or ""
  local text = table.concat({
    "want=" .. (want and "1" or "0"),
    "done=" .. (inbox.done and "1" or "0"),
    "save=" .. save,
    "perm=" .. inbox.perm,
    "",
  }, "\n")
  if text ~= inbox.ctl and writeFile(dir .. "/rom_inbox_ctl.txt", text) then
    inbox.ctl = text
  end
end

local function readStatus()
  local dir = inboxDir()
  if not dir then inbox.status = nil return end
  local f = io.open(dir .. "/rom_inbox_status.txt", "rb")
  if not f then return end
  local text = f:read("*a")
  f:close()
  if not text or text == inbox.raw then return end
  inbox.raw = text
  local st = {}
  for line in text:gmatch("[^\n]+") do
    local k, v = line:match("^(%w+)=(.*)$")
    if k then st[k] = v end
  end
  inbox.status = st
end

-- A tap on the waiting screen asks Android for "All files access", which the
-- storage search needs on Wear OS 4+ to see other apps' files.
local function onTap(imp)
  local st = inbox.status
  if imp.workState == "working" or not st or st.perm ~= "0" then return end
  inbox.perm = inbox.perm + 1
  writeCtl(imp)
end

------------------------------------------------------------------ start --

-- Creates the headless importer main.lua drives while the game is not ready.
-- Always returns it (the caller installs it as main.lua's Importer): it is
-- either already importing (bundled ROM, or one found in the save folder) or
-- waiting for a ROM to appear there.
function WatchBoot.start(RomImporter, onDone)
  local imp = RomImporter.new(function(v)
    -- the game is ready: stop the inbox, and look again for the language
    -- ROM (it may have come over Wi-Fi together with the game ROM)
    inbox.done = true
    writeCtl(nil)
    pcall(function() require("src.core.WatchTranslate").start(v or "firered") end)
    onDone(v)
  end, { launcher = false })
  imp._watchImport = true
  -- The launcher's input handlers expect its view; nothing to click here.
  for _, name in ipairs({ "touchpressed", "touchmoved", "touchreleased",
      "mousepressed", "mousereleased", "mousemoved", "keypressed",
      "textinput", "gamepadpressed", "gamepadreleased", "gamepadaxis",
      "joystickpressed", "joystickreleased", "joystickaxis", "joystickhat",
      "filedropped", "focus" }) do
    imp[name] = swallow
  end
  imp.touchpressed = function(self) onTap(self) end
  imp.mousepressed = function(self, _, _, _, isTouch) if not isTouch then onTap(self) end end
  imp._watchPoll = 0
  imp._watchInbox = 0
  imp.update = function(self, dt)
    self._watchInbox = (self._watchInbox or 0) - (dt or 0)
    if self._watchInbox <= 0 then
      self._watchInbox = WatchBoot.INBOX_SECONDS
      writeCtl(self)
      readStatus()
    end
    if self.workState ~= "working" then
      self._watchPoll = (self._watchPoll or 0) - (dt or 0)
      if self._watchPoll <= 0 then
        self._watchPoll = WatchBoot.POLL_SECONDS
        startFromSaveDir(self)
      end
    end
    return RomImporter.update(self, dt)
  end

  -- RomImporter.new already starts on a ROM it finds in the save folder.
  if imp.workState ~= "working" then
    local bundled = WatchBoot.bundledRom()
    if bundled then
      local ok, data = pcall(love.filesystem.read, bundled)
      if ok and type(data) == "string" and #data > 0 then
        print("[watch] importing bundled ROM " .. bundled)
        -- keeps its "/", so the importer never tries to delete it
        imp:startData(data, bundled)
      end
    end
  end
  if imp.workState ~= "working" then startFromSaveDir(imp) end
  writeCtl(imp)
  return imp
end

-- Back-compat name used by older main.lua patches.
function WatchBoot.startBundledImport(RomImporter, onDone)
  return WatchBoot.start(RomImporter, onDone)
end

------------------------------------------------------------------- draw --

local function fonts(R)
  if not WatchBoot._font or WatchBoot._fontR ~= R then
    local G = love.graphics
    local dpi = (G.getDPIScale and G.getDPIScale()) or 1
    local k = math.max(1, math.floor(R * dpi / 170 + 0.5))
    WatchBoot._font = WatchText.font(22 * k)
    WatchBoot._small = WatchText.font(11 * k)
    WatchBoot._fontR = R
  end
  return WatchBoot._font, WatchBoot._small
end

-- One line centred at height `y` (ink centre, LOVE units): the first font in
-- `list` that fits the circle's width there, else the last one.
local function line(G, list, text, cx, cy, R, y, color)
  local font
  for _, f in ipairs(list) do
    font = f
    local h = f:getHeight()
    local dy = math.max(math.abs(y - h * 0.36 - cy), math.abs(y + h * 0.36 - cy))
    local chord = dy < R and 2 * math.sqrt(R * R - dy * dy) * 0.9 or 0
    if f:getWidth(text) <= chord then break end
  end
  G.setFont(font)
  G.setColor(color[1], color[2], color[3], color[4] or 1)
  local w = font:getWidth(text)
  G.print(text, math.floor(cx - w / 2), math.floor(y - font:getHeight() * 0.48))
end

local WHITE, DIM, FAINT = { 1, 1, 1, 1 }, { 1, 1, 1, 0.75 }, { 1, 1, 1, 0.5 }
local GOOD, BAD = { 0.5, 0.9, 0.5, 1 }, { 1, 0.5, 0.42, 1 }

local function drawQr(G, st, cx, top, side)
  local n = tonumber(st.qrsize)
  local bits = st.qr
  if not n or n < 1 or not bits or #bits < n * n then return false end
  local dpi = (G.getDPIScale and G.getDPIScale()) or 1
  -- whole real pixels per module, with a 2-module white margin
  local px = math.max(1, math.floor(side * dpi / (n + 4)))
  local m = px / dpi
  local full = m * (n + 4)
  local x0 = math.floor((cx - full / 2) * dpi) / dpi
  local y0 = math.floor((top + (side - full) / 2) * dpi) / dpi
  G.setColor(1, 1, 1, 1)
  G.rectangle("fill", x0, y0, full, full, m, m)
  G.setColor(0, 0, 0, 1)
  for y = 0, n - 1 do
    local row = y * n
    local x = 0
    while x < n do
      if bits:byte(row + x + 1) == 49 then -- "1": one run of dark modules
        local run = x
        while run + 1 < n and bits:byte(row + run + 2) == 49 do run = run + 1 end
        G.rectangle("fill", x0 + (x + 2) * m, y0 + (y + 2) * m, (run - x + 1) * m, m)
        x = run + 1
      else
        x = x + 1
      end
    end
  end
  return true
end

-- The waiting screen when the Android side reports: URL + QR, Wi-Fi coming
-- up, no Wi-Fi, a transfer in progress, and what happened to the last file.
local function drawInbox(G, imp, st, cx, cy, R, big, small, lw, accent, t)
  local both = { big, small }
  local title = imp.workState == "error" and "romRefused" or "sendRom"
  local state = st.state or "waiting"
  local p = tonumber(st.progress)

  if state == "receiving" or state == "checking" then
    p = p or 100
    G.setLineWidth(lw)
    G.setColor(accent[1], accent[2], accent[3], 1)
    G.arc("line", "open", cx, cy, R - lw, -math.pi / 2, -math.pi / 2 + (p / 100) * 2 * math.pi, 64)
    line(G, both, WatchText.t("receiving"), cx, cy, R, cy - R * 0.18, WHITE)
    line(G, { big }, ("%d%%"):format(p), cx, cy, R, cy + R * 0.12, WHITE)
    return
  end

  line(G, both, WatchText.t(title), cx, cy, R, cy - R * 0.79, WHITE)
  local note, noteColor
  if st.msg and st.msg ~= "" then
    note, noteColor = st.msg, (state == "accepted") and GOOD or BAD
  end

  if st.url and drawQr(G, st, cx, cy - R * 0.67, R * 0.88) then
    line(G, both, st.url, cx, cy, R, cy + R * 0.34, WHITE)
    line(G, both, note or WatchText.t("scanHint"), cx, cy, R, cy + R * 0.50, noteColor or DIM)
  else
    if st.wifi == "none" then
      line(G, both, WatchText.t("noWifi"), cx, cy, R, cy - R * 0.50, BAD)
      line(G, both, WatchText.t("noWifi2"), cx, cy, R, cy - R * 0.33, DIM)
      line(G, both, WatchText.t("noWifi3"), cx, cy, R, cy - R * 0.19, DIM)
    else
      local a = t * 4
      G.setLineWidth(math.max(3, lw * 0.6))
      G.setColor(accent[1], accent[2], accent[3], 1)
      G.arc("line", "open", cx, cy - R * 0.36, R * 0.13, a, a + 1.4, 20)
      line(G, both, WatchText.t("wifiOn"), cx, cy, R, cy - R * 0.11, DIM)
    end
    line(G, both, WatchText.t("pushTo"), cx, cy, R, cy + R * 0.04, FAINT)
    local dir = (love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or ""
    dir = dir:gsub("^/storage/emulated/0", "/sdcard")
    line(G, { small }, dir, cx, cy, R, cy + R * 0.17, DIM)
    if note then line(G, both, note, cx, cy, R, cy + R * 0.40, noteColor) end
  end

  if st.perm == "0" then
    line(G, both, WatchText.t("tapSearch"), cx, cy, R, cy + R * 0.66, accent)
  elseif st.perm == "1" then
    line(G, both, WatchText.t("searching"), cx, cy, R, cy + R * 0.66, FAINT)
  end
end

-- Round, watch-sized screen for the import (or the wait for a ROM).
function WatchBoot.draw(imp)
  local G = love.graphics
  local cx, cy, R = Watch.face()
  G.push("all")
  G.origin()
  G.clear(0, 0, 0, 1)
  local t = love.timer.getTime()
  local state = imp.workState
  local p = math.max(0, math.min(1, tonumber(imp.progress) or 0))
  local lw = math.max(4, R * 0.05)
  local accent = { 0.95, 0.35, 0.2 }
  local st = inbox.status
  local inboxScreen = st and state ~= "working" and state ~= "complete"
  G.setLineWidth(lw)
  G.setColor(1, 1, 1, 0.12)
  G.circle("line", cx, cy, R - lw, 64)
  if inboxScreen then
    -- drawn by drawInbox
  elseif state == "error" then
    G.setColor(1, 0.35, 0.3, 1)
    G.circle("line", cx, cy, R - lw, 64)
  elseif state == "working" and p > 0 then
    G.setColor(accent[1], accent[2], accent[3], 1)
    G.arc("line", "open", cx, cy, R - lw, -math.pi / 2, -math.pi / 2 + p * 2 * math.pi, 64)
  elseif state == "working" then
    local a = t * 4
    G.setColor(accent[1], accent[2], accent[3], 1)
    G.arc("line", "open", cx, cy, R - lw, a, a + 1.2, 24)
  else
    -- waiting for a ROM: a slow breathing ring
    local k = 0.35 + 0.25 * math.sin(t * 2)
    G.setColor(accent[1], accent[2], accent[3], k)
    G.circle("line", cx, cy, R - lw, 64)
  end
  local big, small = fonts(R)
  local maxW = R * 1.45
  local function centered(font, text, y, alpha)
    G.setFont(font)
    G.setColor(1, 1, 1, alpha or 1)
    G.printf(text, cx - maxW / 2, math.floor(y), maxW, "center")
  end
  if state == "working" or state == "complete" then
    centered(big, WatchText.t("preparing"), cy - R * 0.32)
    centered(small, tostring(imp.status or ""), cy - R * 0.08, 0.75)
    centered(big, ("%d%%"):format(math.floor(p * 100 + 0.5)), cy + R * 0.16)
    centered(small, WatchText.t("firstTime"), cy + R * 0.42, 0.5)
  elseif inboxScreen then
    drawInbox(G, imp, st, cx, cy, R, big, small, lw, accent, t)
  else
    -- no Android inbox (desktop preview): the adb instructions
    local title = WatchText.t(state == "error" and "romRefused" or "sendRom")
    centered(big, title, cy - R * 0.62)
    local detail
    if state == "error" then
      detail = tostring(imp.detail or "")
    else
      detail = "Pokemon FireRed (USA) v1.0 .gba"
    end
    centered(small, detail, cy - R * 0.42, 0.8)
    centered(small, WatchText.t("pushTo"), cy - R * 0.12, 0.6)
    local dir = (love.filesystem.getSaveDirectory and love.filesystem.getSaveDirectory()) or ""
    dir = dir:gsub("^/storage/emulated/0", "/sdcard")
    centered(small, dir, cy + R * 0.02, 0.9)
    centered(small, WatchText.t("autoStart"), cy + R * 0.55, 0.5)
  end
  G.pop()
end

return WatchBoot
