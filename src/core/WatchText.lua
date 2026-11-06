-- Wear OS: language of the watch's own screens, picked from the device.
--
-- WearGameActivity puts the Android locale in POKEPORT_LOCALE before LOVE
-- starts (a watch set to Portuguese (Brazil) reports "pt-BR"); desktop
-- previews fall back to LANG / LC_ALL.  Watch.config.language overrides it
-- ("auto" = follow the device).  Supported: Portuguese (Brazil), Spanish,
-- English, French, German, Italian, Russian; anything else reads as English.
--
-- Covers what the watch port itself draws (first-run / import screens and
-- the controls cheat-sheet, laid out to fit the round face).  The game's own
-- text comes from the ROM: src/core/WatchTranslate.lua swaps in the same
-- language's FireRed ROM text when that ROM is on the watch, and
-- applyTranslationMods() switches on a translation mod matching this
-- language (when installed or bundled) and off the others.
--
-- Text is drawn with the engine's bundled Plain Pixel TTF (CC-BY 4.0,
-- assets/fonts/plainpixel), which covers Latin accents and Cyrillic.

local Watch = require("src.core.Watch")

local WatchText = {}

WatchText.SUPPORTED = { pt = true, es = true, en = true, fr = true, de = true, it = true, ru = true }

-- translation mods the watch knows how to pick by language; a mod may also
-- declare `"language": "pt"` (or "pt-BR") in its manifest
WatchText.TRANSLATION_MODS = {
  ["definitiv-german-gen3"] = "de",
}

local cachedLang

local function normalize(tag)
  if type(tag) ~= "string" then return nil end
  local code = tag:match("^%s*([A-Za-z][A-Za-z])")
  code = code and code:lower() or nil
  if code and WatchText.SUPPORTED[code] then return code end
  return nil
end

function WatchText.locale()
  return os.getenv("POKEPORT_LOCALE") or os.getenv("LC_ALL")
    or os.getenv("LC_MESSAGES") or os.getenv("LANG") or ""
end

function WatchText.lang()
  if cachedLang then return cachedLang end
  local forced = Watch.config.language
  cachedLang = (forced and forced ~= "auto" and normalize(forced))
    or normalize(WatchText.locale()) or "en"
  return cachedLang
end

function WatchText._setLangForTests(code) cachedLang = code end

local T = {
  preparing = {
    pt = "Preparando FireRed", es = "Preparando FireRed", en = "Preparing FireRed",
    fr = "Préparation de FireRed", de = "FireRed wird vorbereitet", ru = "Подготовка FireRed",
    it = "Preparazione di FireRed",
  },
  firstTime = {
    pt = "Só na primeira vez", es = "Solo la primera vez", en = "Only the first time",
    fr = "Seulement la première fois", de = "Nur beim ersten Mal", ru = "Только в первый раз",
    it = "Solo la prima volta",
  },
  sendRom = {
    pt = "Envie a ROM", es = "Envía la ROM", en = "Send the ROM",
    fr = "Envoyez la ROM", de = "ROM senden", ru = "Отправьте ROM", it = "Invia la ROM",
  },
  romRefused = {
    pt = "ROM recusada", es = "ROM rechazada", en = "ROM rejected",
    fr = "ROM refusée", de = "ROM abgelehnt", ru = "ROM отклонён", it = "ROM rifiutata",
  },
  pushTo = {
    pt = "adb push para:", es = "adb push a:", en = "adb push to:",
    fr = "adb push vers :", de = "adb push nach:", ru = "adb push в:", it = "adb push in:",
  },
  loading3d = {
    pt = "Carregando 3D", es = "Cargando 3D", en = "Loading 3D",
    fr = "Chargement 3D", de = "3D wird geladen", ru = "Загрузка 3D", it = "Caricamento 3D",
  },
  autoStart = {
    pt = "Começa sozinho ao chegar", es = "Empieza solo al llegar",
    en = "Starts as soon as it arrives", fr = "Démarre dès son arrivée",
    de = "Startet automatisch", ru = "Начнётся автоматически", it = "Parte appena arriva",
  },
  wifiOn = {
    pt = "Ligando o Wi-Fi...", es = "Encendiendo el Wi-Fi...", en = "Turning Wi-Fi on...",
    fr = "Activation du Wi-Fi...", de = "WLAN wird aktiviert...", it = "Accensione Wi-Fi...",
    ru = "Включение Wi-Fi...",
  },
  scanHint = {
    pt = "Celular ou PC no mesmo Wi-Fi", es = "Móvil o PC en el mismo Wi-Fi", en = "Phone or PC on the same Wi-Fi",
    fr = "Téléphone ou PC, même Wi-Fi", de = "Handy oder PC im selben WLAN", it = "Telefono o PC, stesso Wi-Fi",
    ru = "Телефон или ПК в той же Wi-Fi",
  },
  noWifi = {
    pt = "Sem Wi-Fi", es = "Sin Wi-Fi", en = "No Wi-Fi",
    fr = "Pas de Wi-Fi", de = "Kein WLAN", it = "Nessun Wi-Fi",
    ru = "Нет Wi-Fi",
  },
  noWifi2 = {
    pt = "Conecte o relógio a uma rede", es = "Conecta el reloj a una red", en = "Connect the watch to a network",
    fr = "Connectez la montre à un réseau", de = "Verbinde die Uhr mit einem Netz", it = "Collega l'orologio a una rete",
    ru = "Подключите часы к сети",
  },
  noWifi3 = {
    pt = "ou ao hotspot do celular", es = "o al hotspot del móvil", en = "or to your phone's hotspot",
    fr = "ou au partage du téléphone", de = "oder mit dem Handy-Hotspot", it = "o all'hotspot del telefono",
    ru = "или к точке доступа телефона",
  },
  receiving = {
    pt = "Recebendo ROM", es = "Recibiendo ROM", en = "Receiving ROM",
    fr = "Réception de la ROM", de = "ROM wird empfangen", it = "Ricezione ROM",
    ru = "Приём ROM",
  },
  tapSearch = {
    pt = "Toque: achar .gba no relógio", es = "Toca: buscar .gba en el reloj", en = "Tap: find .gba on the watch",
    fr = "Touchez : chercher un .gba", de = "Tippen: .gba auf der Uhr suchen", it = "Tocca: cerca .gba sull'orologio",
    ru = "Нажмите: найти .gba на часах",
  },
  searching = {
    pt = "Procurando .gba no relógio", es = "Buscando .gba en el reloj", en = "Looking for .gba on the watch",
    fr = "Recherche de .gba sur la montre", de = "Suche .gba auf der Uhr", it = "Cerco .gba sull'orologio",
    ru = "Ищу .gba на часах",
  },
  preparingLang = {
    pt = "Preparando o idioma", es = "Preparando el idioma", en = "Preparing language",
    fr = "Préparation de la langue", de = "Sprache wird vorbereitet", ru = "Подготовка языка",
    it = "Preparazione della lingua",
  },
}

local HINTS = {
  pt = { "CONTROLES", "Deslize e segure: andar", "Arraste longe: correr",
         "Cima: L  SELECT  R", "Meio: B esq.  A dir.", "Embaixo: START",
         "2º dedo andando: botão", "3 toques c/ 2 dedos: 3D", "Coroa: rolar / zoom" },
  es = { "CONTROLES", "Desliza y mantén: andar", "Arrastra lejos: correr",
         "Arriba: L  SELECT  R", "Centro: B izq.  A der.", "Abajo: START",
         "2º dedo andando: botón", "3 toques con 2 dedos: 3D", "Corona: mover / zoom" },
  en = { "CONTROLS", "Swipe and hold: walk", "Drag far: run",
         "Top: L  SELECT  R", "Middle: B left  A right", "Bottom: START",
         "2nd finger walking: button", "2-finger triple tap: 3D", "Crown: scroll / zoom" },
  fr = { "COMMANDES", "Glisser et tenir : marcher", "Glisser loin : courir",
         "Haut : L  SELECT  R", "Milieu : B gauche  A droite", "Bas : START",
         "2e doigt en marchant : bouton", "Double toucher à 3 doigts : 3D", "Couronne : défiler / zoom" },
  de = { "STEUERUNG", "Wischen und halten: gehen", "Weit ziehen: rennen",
         "Oben: L  SELECT  R", "Mitte: B links  A rechts", "Unten: START",
         "2. Finger beim Gehen: Taste", "Doppeltipp mit 3 Fingern: 3D", "Krone: blättern / Zoom" },
  it = { "COMANDI", "Scorri e tieni: cammina", "Trascina lontano: corri",
         "Su: L  SELECT  R", "Centro: B sin.  A des.", "Giù: START",
         "2º dito camminando: tasto", "Doppio tocco a 3 dita: 3D", "Corona: scorri / zoom" },
  ru = { "УПРАВЛЕНИЕ", "Свайп и держать: ходьба", "Тянуть дальше: бег",
         "Верх: L  SELECT  R", "Центр: B слева  A справа", "Низ: START",
         "2-й палец при ходьбе: кнопка", "2 касания 3 пальцами: 3D", "Колесо: прокрутка / зум" },
}

function WatchText.t(key)
  local row = T[key]
  if not row then return key end
  return row[WatchText.lang()] or row.en or key
end

function WatchText.hintLines()
  return HINTS[WatchText.lang()] or HINTS.en
end

------------------------------------------------------------------ font --

WatchText.FONT = "assets/fonts/plainpixel/PlainPixel-Regular.ttf"
local fonts = {}

-- The pixel font at `px` real screen pixels (a multiple of 11 keeps its
-- 5x11 grid crisp).  Falls back to LOVE's default font.
function WatchText.font(px)
  px = math.max(6, math.floor(px + 0.5))
  if fonts[px] then return fonts[px] end
  local G = love.graphics
  local dpi = (G.getDPIScale and tonumber(G.getDPIScale())) or 1
  if dpi <= 0 then dpi = 1 end
  local ok, f = pcall(G.newFont, WatchText.FONT, px / dpi, "mono", dpi)
  if not ok or not f then
    ok, f = pcall(G.newFont, px / dpi)
    if not ok then f = G.getFont() end
  end
  if f.setFilter then pcall(f.setFilter, f, "nearest", "nearest") end
  fonts[px] = f
  return f
end

-- The biggest crisp pixel size whose widest line fits `maxW` LOVE units,
-- starting from about `wantPx` real pixels.
function WatchText.fitFont(lines, maxW, wantPx)
  local G = love.graphics
  local dpi = (G.getDPIScale and tonumber(G.getDPIScale())) or 1
  local k = math.max(1, math.floor((wantPx or 22) / 11 + 0.5))
  while k >= 1 do
    local f = WatchText.font(11 * k)
    local widest = 0
    for _, line in ipairs(lines) do widest = math.max(widest, f:getWidth(line)) end
    if widest <= maxW then return f end
    k = k - 1
  end
  -- even 11 px is too wide: a smaller, non-grid size
  local f = WatchText.font(11)
  local widest = 1
  for _, line in ipairs(lines) do widest = math.max(widest, f:getWidth(line)) end
  return WatchText.font(math.max(6, math.floor(11 * maxW / widest)))
end

-- Where the pixel font's ink sits inside its line box, as fractions of
-- getHeight(): the TTF reserves a tall ascent/descent, so the visible glyphs
-- (accents and descenders included) only span about 14%..82% of it.
local INK_TOP, INK_BOTTOM = 0.12, 0.84

-- Stacks `lines` centred on (0, 0) with `font`; line 1 (the title) gets a
-- little extra room below it; `spacing` is the line pitch in line heights
-- (0.80 is tight but clear).  Returns the print y of each line relative to
-- the centre, or nil when some line, at the top or bottom of its glyphs,
-- is wider than the circle of radius `r` at that height.
function WatchText.circleLayout(font, lines, r, spacing, force)
  local h = font:getHeight()
  local pitch = h * (spacing or 0.80)
  local gap = pitch * 0.30
  local ys, y = {}, 0
  for i = 1, #lines do
    ys[i] = y
    y = y + pitch + (i == 1 and gap or 0)
  end
  local off = -((ys[1] + INK_TOP * h) + (ys[#ys] + INK_BOTTOM * h)) / 2
  local pad = h * 0.10
  for i, line in ipairs(lines) do
    ys[i] = ys[i] + off
    if not force then
      local dy = math.max(math.abs(ys[i] + INK_TOP * h), math.abs(ys[i] + INK_BOTTOM * h))
      if dy >= r then return nil end
      local chord = 2 * math.sqrt(r * r - dy * dy)
      if font:getWidth(line) > chord - pad then return nil end
    end
  end
  return ys
end

-- The biggest crisp pixel size (from about `wantPx` real pixels down) at
-- which `lines` fit inside a circle of radius `r` LOVE units, every line
-- within the circle's width at its own height.  Returns the font and the
-- print y of each line relative to the circle's centre.  When there is room
-- the lines are spread a little further apart.
function WatchText.fitCircle(lines, r, wantPx)
  local sizes = {}
  for k = math.max(1, math.floor((wantPx or 22) / 11 + 0.5)), 1, -1 do
    sizes[#sizes + 1] = 11 * k
  end
  for px = 10, 6, -1 do sizes[#sizes + 1] = px end
  for _, px in ipairs(sizes) do
    local f = WatchText.font(px)
    for _, spacing in ipairs({ 1.05, 0.95, 0.80 }) do
      local ys = WatchText.circleLayout(f, lines, r, spacing)
      if ys then return f, ys end
    end
  end
  local f = WatchText.font(6)
  return f, WatchText.circleLayout(f, lines, r, 0.80, true)
end

----------------------------------------------------- translation mods --

local function readManifest(path)
  local ok, raw = pcall(love.filesystem.read, path .. "/manifest.json")
  if not ok or type(raw) ~= "string" then return nil end
  return raw
end

-- Turn the translation mod for the device language on, and the other known
-- translation mods off, for `version` (the game about to boot).  Runs before
-- the mod loader reads options, so it applies to this very boot.
function WatchText.applyTranslationMods(version)
  local fs = love.filesystem
  local okList, items = pcall(fs.getDirectoryItems, "mods")
  if not okList or type(items) ~= "table" then return end
  local lang = WatchText.lang()
  local SaveData = require("src.core.SaveData")
  local okO, options = pcall(SaveData.loadOptions)
  if not okO or type(options) ~= "table" then return end
  local changed = false
  for _, folder in ipairs(items) do
    local raw = readManifest("mods/" .. folder)
    if raw then
      local id = raw:match('"id"%s*:%s*"([^"]+)"') or folder
      local declared = raw:match('"language"%s*:%s*"([^"]+)"')
      local modLang = WatchText.TRANSLATION_MODS[id] or normalize(declared)
      if modLang then
        local want = (modLang == lang)
        if SaveData.modEnabled(options, id, version) ~= want then
          SaveData.setModEnabled(options, id, want, version)
          changed = true
        end
      end
    end
  end
  if changed then pcall(SaveData.saveOptions, options) end
end

return WatchText
