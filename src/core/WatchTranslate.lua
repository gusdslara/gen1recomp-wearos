-- Wear OS: the game's own text in the watch's language.
--
-- The game reads its dialogue from the player's FireRed (USA) ROM.  For
-- another language the watch also needs that language's FireRed ROM (an
-- official one, or the USA ROM with a fan translation patch applied) plus a
-- *recipe* from mobile/android/wear/translation-tool/: for every named text
-- of src/import/gba/versions_text.lua, the address of the same text in the
-- other ROM.  Recipes hold addresses only; every word shown comes from the
-- player's own ROM.
--
-- On the first launch in a language (or after the recipe or the ROM change)
-- the texts are decoded once and cached in the save folder (CACHE_DIR);
-- later launches just load that cache.  When the script bundle loads, the
-- translated texts replace the English ones (patchBundle, called from
-- src/core/game3/scripting/space.lua).  Text the recipe does not cover yet,
-- or that does not decode cleanly, stays in English.
--
-- The font comes from the translated ROM too: a fan patch redraws glyphs for
-- its own letters (the Brazilian patch draws ã/õ where the US font has ä/ö),
-- so its text only reads right with its own font.
--
-- Language ROM: <save folder>/idioma/<file>, or game.love idioma/<file> in a
-- debug build (mobile/android/wear/build.gradle packs rom-sources/ there).

local Watch = require("src.core.Watch")
local WatchText = require("src.core.WatchText")

local WT = {}

WT.FORMAT = 1
WT.RECIPE_DIR = "watchlang"            -- game.love, every build
WT.ROM_DIR = "idioma"                  -- save folder (adb push) or game.love (debug)
WT.CACHE_DIR = "watchlang-cache"       -- save folder
WT.TEXT_MAX = 1024

-- Per watch language: the recipe, the ROM file names looked for, and the
-- game code in that ROM's header (fan patches keep the US "BPRE").
WT.LANGS = {
  pt = { recipe = "recipe_ptbr.json", code = "BPRE",
         roms = { "firered_ptbr.gba", "firered_pt.gba", "firered_pt-br.gba", "firered_pt_br.gba" } },
  es = { recipe = "recipe_es_fanpatch.json", code = "BPRE", roms = { "firered_es.gba" } },
  fr = { recipe = "recipe_fr.json", code = "BPRF", roms = { "firered_fr.gba" } },
  it = { recipe = "recipe_it.json", code = "BPRI", roms = { "firered_it.gba" } },
}

-- Widths of glyphs 0xA1-0xEE (digits, punctuation, A-Z, a-z) in the US
-- normal and small fonts.  Used only to find each font inside a translated
-- ROM, which may have moved it (sFontNormalLatinGlyphWidths @ 0x207300,
-- sFontSmallLatinGlyphWidths @ 0x1EEF00).
local NORMAL_WIDTHS = { 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 6, 5, 6, 6, 6, 3, 3, 6, 6, 8, 5, 9, 6,
  6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 6, 5, 6, 6,
  4, 6, 5, 5, 6, 5, 6, 6, 6, 5, 5, 5, 6, 6, 6, 6, 6, 6 }
local SMALL_WIDTHS = { 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 8, 5, 8, 5,
  5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 4, 5, 5, 5, 5, 4, 5, 5, 5, 5, 5, 5, 5, 5, 5,
  4, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5, 5 }

-- Where the US code keeps the font pointers (pokefirered src/text.c); a patch
-- that only redraws glyphs leaves them pointing at its font.
-- `hashes`: a checksum (h = h*31 + byte, mod 2^31-1) of each US glyph
-- 0xBB-0xEE (A-Z, a-z), to recognise the font wherever a ROM keeps it.
local FONTS = {
  normal = { usGlyphs = 0x1FF300, usWidths = 0x207300, glyphSize = 64, widthsGap = 0x8000,
             glyphPtrAt = 0x66EC, widthsPtrAt = 0x66F4, widths = NORMAL_WIDTHS, rows = 14,
             hashes = { 1842074044, 740081956, 1933552650, 1750079695, 1854891538, 643077506,
               934899274, 1151026901, 1599834826, 1363121672, 1085348755, 259097400, 996875212,
               265289145, 1283793125, 153262836, 281650002, 1993995782, 1797715935, 802413266,
               1057411886, 1429607169, 392336475, 882264955, 1108795875, 855535948, 2125640968,
               5983894, 660526900, 881643063, 1342657633, 795628274, 1100235331, 1436086145,
               1496606004, 800573922, 181160714, 1370232045, 2109618635, 870873973, 713587271,
               1619094784, 1495956772, 1861971024, 1466275108, 1746450891, 2115577770, 594861337,
               872682271, 836674231, 1209523287, 897797755 } },
  small = { usGlyphs = 0x1EAF00, usWidths = 0x1EEF00, glyphSize = 32, widthsGap = 0x4000,
            glyphPtrAt = 0x64C4, widthsPtrAt = 0x64CC, widths = SMALL_WIDTHS, rows = 16,
            hashes = { 1007460848, 1575175920, 1651027939, 1440410838, 412325004, 1236234161,
              1362150839, 264065020, 1605369296, 1853666845, 668073837, 1257906335, 1347840820,
              383025173, 408360433, 341353656, 1748531540, 2107555164, 1100940848, 1659371836,
              1812448252, 1323573650, 56796275, 1351854470, 125966054, 641656461, 690212458,
              2048696384, 1734429104, 1961717294, 1484424744, 871064556, 1192365367, 433591981,
              727458480, 227055399, 1835512021, 1174851638, 813180893, 241960018, 901321642,
              305992683, 120625416, 837633195, 1522119289, 575404250, 1837055612, 1978678457,
              2102951690, 808987105, 191724874, 1930593346 } },
}

WT.active = nil   -- { lang, entries = { {name, key, ir}, ... }, font = {...} }
WT.status = nil   -- last outcome, for logcat and the diagnostics panel

local function log(msg)
  WT.status = msg
  print("[watch-lang] " .. msg)
end

------------------------------------------------------------------ files --

local fs = function() return love and love.filesystem end

local function fileInfo(path)
  local f = fs()
  if not (f and f.getInfo) then return nil end
  local ok, info = pcall(f.getInfo, path, "file")
  return ok and info or nil
end

local function readFile(path)
  local ok, data = pcall(fs().read, path)
  if ok and type(data) == "string" then return data end
  return nil
end

-- The first ROM of the language that exists (save folder first: LOVE's
-- filesystem looks there before game.love).
function WT.findRom(spec)
  local f = fs()
  local items = {}
  if f and f.getDirectoryItems then
    local ok, list = pcall(f.getDirectoryItems, WT.ROM_DIR)
    if ok and type(list) == "table" then
      for _, name in ipairs(list) do items[name:lower()] = name end
    end
  end
  for _, want in ipairs(spec.roms) do
    local name = items[want:lower()]
    if name then
      local path = WT.ROM_DIR .. "/" .. name
      local info = fileInfo(path)
      if info and (info.size or 0) >= 0x800000 then return path, info end
    end
  end
  return nil
end

------------------------------------------------------------- serialize --

local function ser(v, out)
  local t = type(v)
  if t == "string" then
    out[#out + 1] = string.format("%q", v)
  elseif t == "number" or t == "boolean" then
    out[#out + 1] = tostring(v)
  elseif t == "table" then
    out[#out + 1] = "{"
    local n = #v
    for i = 1, n do ser(v[i], out); out[#out + 1] = "," end
    for k, x in pairs(v) do
      if not (type(k) == "number" and k >= 1 and k <= n and k % 1 == 0) then
        out[#out + 1] = "["
        ser(k, out)
        out[#out + 1] = "]="
        ser(x, out)
        out[#out + 1] = ","
      end
    end
    out[#out + 1] = "}"
  else
    out[#out + 1] = "nil"
  end
end

-- `return { meta = ..., entries = {...} }`, the entries split into small
-- functions so no single chunk runs into LuaJIT's constant limits.
local function serializeCache(meta, entries)
  local out = { "local E = {}\n" }
  for i = 1, #entries, 200 do
    out[#out + 1] = "do (function(E)\n"
    for j = i, math.min(i + 199, #entries) do
      out[#out + 1] = "E[" .. j .. "]="
      ser(entries[j], out)
      out[#out + 1] = "\n"
    end
    out[#out + 1] = "end)(E) end\n"
  end
  out[#out + 1] = "local M = "
  ser(meta, out)
  out[#out + 1] = "\nreturn { meta = M, entries = E }\n"
  return table.concat(out)
end

------------------------------------------------------------------ text --

local function u32(rom, off)
  local a, b, c, d = rom:byte(off + 1, off + 4)
  if not d then return nil end
  return a + b * 256 + c * 65536 + d * 16777216
end

local function headerCode(rom)
  return rom:sub(0xAD, 0xB0)
end

-- The full Latin charset: the decode table plus the accented letters only
-- other languages print (pokefirered charmap.txt; FrlgFont draws them all).
local function latinCharmap(TextIR)
  local map = {}
  for k, v in pairs(TextIR.CHARMAP) do map[k] = v end
  local okF, FrlgFont = pcall(require, "src.ui.game3.frlg_font")
  for k, v in pairs(okF and FrlgFont.LATIN_GLYPHS or {}) do
    if map[k] == nil then map[k] = v end
  end
  return map
end

local LETTER = {}
for c = 0xBB, 0xEE do LETTER[c] = true end

-- Length (terminator included) and quality of the string at `off`: unknown
-- character codes, and how much of it reads as letters.  Addresses a recipe
-- got wrong land in code or graphics, which fails here.
local function scan(rom, off, TextIR, charmap, extra)
  local i, last = off + 1, math.min(#rom, off + WT.TEXT_MAX)
  local unknown, chars, letters = 0, 0, 0
  while i <= last do
    local c = rom:byte(i)
    if c == 0xFF then
      return i - off, unknown, chars, letters
    elseif c == 0xFD or c == 0xF7 or c == 0xF8 or c == 0xF9 then
      i = i + 2
    elseif c == 0xFC then
      i = i + 2 + (TextIR.EXT_ARGS[rom:byte(i + 1) or 0] or 0)
    elseif c == 0xFA or c == 0xFB or c == 0xFE then
      i = i + 1
    else
      if charmap[c] or TextIR.LIGATURE[c] or (extra and extra[c]) then
        chars = chars + 1
        if LETTER[c] or (c >= 0x01 and c <= 0x2B) or (c >= 0xF1 and c <= 0xF6)
            or c == 0x5A or c == 0x68 or c == 0x6F then
          letters = letters + 1
        end
      else
        unknown = unknown + 1
      end
      i = i + 1
    end
  end
  return nil, unknown, chars, letters
end

local function parseRecipe(src)
  local recipe, n = {}, 0
  for name, off in src:gmatch('"([^"]+)"%s*:%s*(%d+)') do
    recipe[#recipe + 1] = { name = name, off = tonumber(off) }
    n = n + 1
  end
  table.sort(recipe, function(a, b) return a.name < b.name end)
  return recipe, n
end

-- Decodes every recipe text from `rom`.  Returns the entries and counts.
function WT.decodeTexts(rom, recipe)
  local TextIR = require("src.core.game3.scripting.text_ir")
  local VT = require("src.import.gba.versions_text")
  local named, battle = VT.NAMED_TEXTS or {}, VT.NAMED_BATTLE_TEXTS or {}
  local charmap = latinCharmap(TextIR)
  local extra = TextIR.dialect(TextIR.DEFAULT_DIALECT).CHARMAP_EXTRA
  local entries, stats = {}, { ok = 0, bad = 0, unknownName = 0 }
  -- TextIR.decode reads its module-level table: lend it the full Latin set
  -- for this pass only, so the US import path never changes.
  local added = {}
  for k, v in pairs(charmap) do
    if TextIR.CHARMAP[k] == nil then TextIR.CHARMAP[k] = v; added[#added + 1] = k end
  end
  local ok, err = pcall(function()
    for _, row in ipairs(recipe) do
      local us = named[row.name] or battle[row.name]
      local len, unknown, chars, letters = scan(rom, row.off, TextIR, charmap, extra)
      local plausible = len and unknown == 0 and (chars < 6 or letters >= chars * 0.45)
      if not us then
        stats.unknownName = stats.unknownName + 1
      elseif not plausible then
        stats.bad = stats.bad + 1
      else
        -- FireRed's dialect, named so decode never asks which game is running
        local ir = TextIR.decode(rom:sub(row.off + 1, row.off + len),
          { battle = battle[row.name] and true or nil, dialect = TextIR.DEFAULT_DIALECT })
        entries[#entries + 1] = { row.name, string.format("g3:%08x", 0x08000000 + us), ir }
        stats.ok = stats.ok + 1
      end
    end
  end)
  for _, k in ipairs(added) do TextIR.CHARMAP[k] = nil end
  if not ok then error(err, 0) end
  return entries, stats
end

------------------------------------------------------------------ font --

local function widthsMatch(rom, base, want)
  local hit = 0
  for i, w in ipairs(want) do
    if rom:byte(base + 0xA1 + i) == w then hit = hit + 1 end
  end
  return hit >= #want * 0.8
end

local function glyphHash(rom, off, size)
  local h = 0
  for i = off + 1, off + size do h = (h * 31 + rom:byte(i)) % 2147483647 end
  return h
end

-- How many of the letters A-Z a-z at `glyphs` are drawn exactly like the US
-- font's (compared by hash).  A patch redraws a few letters at most; text or
-- code that took a font's old place matches none.
local function fontScore(rom, glyphs, f)
  if glyphs < 0 or glyphs + 0xF0 * f.glyphSize > #rom then return 0 end
  local n = 0
  for i, want in ipairs(f.hashes) do
    if glyphHash(rom, glyphs + (0xBA + i) * f.glyphSize, f.glyphSize) == want then n = n + 1 end
  end
  return n
end

-- Glyph and width table offsets of one font inside `rom`, or nil.  Tries the
-- pointer the US code reads, then every width table that looks like the US
-- one; keeps the first whose letters look like the font.
function WT.findFont(rom, which)
  local f = FONTS[which]
  local candidates = {}
  local gp, wp = u32(rom, f.glyphPtrAt), u32(rom, f.widthsPtrAt)
  if gp and wp and gp >= 0x08000000 and gp < 0x09000000 and wp >= 0x08000000 and wp < 0x09000000
      and widthsMatch(rom, wp - 0x08000000, f.widths) then
    candidates[#candidates + 1] = { gp - 0x08000000, wp - 0x08000000, "pointer" }
  end
  local needle = string.char((table.unpack or unpack)(f.widths))
  local at = rom:find(needle, 1, true)
  while at and #candidates < 8 do
    local widths = at - 1 - 0xA1
    candidates[#candidates + 1] = { widths - f.widthsGap, widths, "search" }
    at = rom:find(needle, at + 1, true)
  end
  for _, c in ipairs(candidates) do
    if fontScore(rom, c[1], f) >= 20 then return c[1], c[2], c[3] end
  end
  return nil
end

-- The GBA prints a glyph only up to its width (and the normal font only 14
-- rows tall); a patched font may keep scraps outside that box, which this
-- engine would draw since it blits whole 16x16 cells.
local function clipSheet(rgba, widths, rows)
  local blankCell, blankLine = string.rep("\0", 64), string.rep("\0", 1024)
  local out = {}
  for y = 0, 511 do
    if y % 16 >= rows then
      out[#out + 1] = blankLine
    else
      local line, parts = rgba:sub(y * 1024 + 1, y * 1024 + 1024), {}
      for col = 0, 15 do
        local w = tonumber(widths[math.floor(y / 16) * 16 + col]) or 16
        w = math.max(0, math.min(16, w))
        parts[col + 1] = line:sub(col * 64 + 1, col * 64 + w * 4) .. blankCell:sub(1, (16 - w) * 4)
      end
      out[#out + 1] = table.concat(parts)
    end
  end
  return table.concat(out)
end

-- The translated ROM's normal and small fonts as the RGBA sheets FrlgFont
-- draws from (the importer's own decoder, pointed at the moved tables).  A
-- font that cannot be found stays the US one: official translations use the
-- same glyph codes for the same letters.
function WT.extractFonts(rom)
  local Chrome = require("src.import.gba.text_chrome_extract")
  local out, found = {}, false
  for _, which in ipairs({ "normal", "small" }) do
    local f = FONTS[which]
    local glyphs, widths, how = WT.findFont(rom, which)
    if glyphs then
      local gEnd, wEnd = f.usGlyphs + 512 * f.glyphSize, f.usWidths + 512
      local proxy = {
        get = function(_, o)
          if o >= f.usGlyphs and o < gEnd then o = o - f.usGlyphs + glyphs
          elseif o >= f.usWidths and o < wEnd then o = o - f.usWidths + widths end
          return rom:byte(o + 1)
        end,
      }
      local sheet = which == "normal" and Chrome.extractLatinNormal(proxy) or Chrome.extractLatinSmall(proxy)
      out[which] = { fg = clipSheet(sheet.fgRgba, sheet.widths, f.rows),
                     sh = clipSheet(sheet.shRgba, sheet.widths, f.rows),
                     widths = sheet.widths, at = string.format("0x%X/%s", glyphs, how) }
      found = true
    end
  end
  return found and out or nil
end

local ATLAS_GAP = 16 -- src/ui/game3/frlg_font.lua

local function packAtlas(fgData, shData, quads)
  local ok, atlas = pcall(function()
    local w, h = fgData:getDimensions()
    local off = h + ATLAS_GAP
    local data = love.image.newImageData(w, off + h, "rgba8")
    data:paste(fgData, 0, 0, 0, 0, w, h)
    data:paste(shData, 0, off, 0, 0, w, h)
    local img = love.graphics.newImage(data)
    img:setFilter("nearest", "nearest")
    local aw, ah = img:getDimensions()
    local fq, sq = {}, {}
    for id, q in pairs(quads) do
      local qx, qy, qw, qh = q:getViewport()
      fq[id] = love.graphics.newQuad(qx, qy, qw, qh, aw, ah)
      sq[id] = love.graphics.newQuad(qx, qy + off, qw, qh, aw, ah)
    end
    return { image = img, fg = fq, sh = sq, src = quads }
  end)
  return ok and atlas or nil
end

local function sheetImages(fgRgba, shRgba)
  local fgData = love.image.newImageData(256, 512, "rgba8", fgRgba)
  local shData = love.image.newImageData(256, 512, "rgba8", shRgba)
  local fg, sh = love.graphics.newImage(fgData), love.graphics.newImage(shData)
  fg:setFilter("nearest", "nearest")
  sh:setFilter("nearest", "nearest")
  local quads = {}
  for id = 0, 511 do
    quads[id] = love.graphics.newQuad((id % 16) * 16, math.floor(id / 16) * 16, 16, 16, 256, 512)
  end
  return fg, sh, quads, packAtlas(fgData, shData, quads)
end

-- Puts the translated fonts in FrlgFont's slots (its own loader only fills
-- empty ones), and again after anything invalidates them.
function WT.installFont(font)
  if not (font and love and love.graphics and love.image) then return false end
  local FrlgFont = require("src.ui.game3.frlg_font")
  local ok, err = pcall(function()
    if font.normal then
      local fg, sh, quads, atlas = sheetImages(font.normal.fg, font.normal.sh)
      FrlgFont._fg, FrlgFont._sh, FrlgFont._quads, FrlgFont._atlas = fg, sh, quads, atlas
      FrlgFont._widths = font.normal.widths
    end
    if font.small then
      local sfg, ssh, squads, satlas = sheetImages(font.small.fg, font.small.sh)
      FrlgFont._small = { fg = sfg, sh = ssh, quads = squads, widths = font.small.widths,
                          _romBaked = true, atlas = satlas }
    end
    FrlgFont._rev = nil
  end)
  if not ok then log("font not installed: " .. tostring(err)) return false end
  if not FrlgFont._watchLangHook then
    FrlgFont._watchLangHook = true
    local invalidate = FrlgFont.invalidate
    FrlgFont.invalidate = function(...)
      invalidate(...)
      if WT.active and WT.active.font then WT.installFont(WT.active.font) end
    end
  end
  return true
end

---------------------------------------------------------------- bundle --

-- Kinds of value a text pulls in when shown (player name, buffers, battle
-- placeholders).  A translation may drop one but never add one the English
-- text does not fill, or the game would print garbage or stall.
local VALUE_SEG = { player = true, rival = true, strvar = true, ph = true, bph = true, dynamic = true }

local function valueSet(ir)
  local set = {}
  for _, seg in ipairs(type(ir) == "table" and ir or {}) do
    if type(seg) == "table" and VALUE_SEG[seg.t] then
      set[seg.t .. ":" .. tostring(seg.n or seg.code or "")] = true
    end
  end
  return set
end

local function safeSwap(us, tr)
  if type(us) ~= "table" then return true end
  local have = valueSet(us)
  for k in pairs(valueSet(tr)) do
    if not have[k] then return false end
  end
  return true
end

-- Called from Space.ensureBundle (WEAROS-PATCH) every time the script
-- bundle loads: the translated texts replace the English ones in place.
function WT.patchBundle(bundle)
  local a = WT.active
  if not (a and bundle and type(bundle.text) == "table") or bundle._watchLang == a.lang then return end
  local text, n, skipped = bundle.text, 0, 0
  for _, e in ipairs(a.entries) do
    local name, key, ir = e[1], e[2], e[3]
    local us = text[name] or text[key]
    if safeSwap(us, ir) then
      text[name] = ir
      if text[key] ~= nil then text[key] = ir end
      n = n + 1
    else
      skipped = skipped + 1
    end
  end
  bundle._watchLang = a.lang
  log(string.format("%s: %d texts translated (%d kept in English: placeholders differ)", a.lang, n, skipped))
end

------------------------------------------------------------------ boot --

local function drawPreparing()
  local G = love and love.graphics
  if not (G and G.present and G.isActive and G.isActive()) then return end
  pcall(function()
    local cx, cy, R = Watch.face()
    G.push("all")
    G.origin()
    G.clear(0, 0, 0, 1)
    local dpi = (G.getDPIScale and G.getDPIScale()) or 1
    local font = WatchText.font(22 * math.max(1, math.floor(R * dpi / 170 + 0.5)))
    G.setFont(font)
    G.setColor(1, 1, 1, 1)
    local w = R * 1.45
    G.printf(WatchText.t("preparingLang"), cx - w / 2, cy - font:getHeight() / 2, w, "center")
    G.setLineWidth(math.max(4, R * 0.05))
    G.setColor(0.95, 0.35, 0.2, 1)
    G.circle("line", cx, cy, R - math.max(4, R * 0.05), 64)
    G.pop()
    G.present()
  end)
end

local function cachePaths(lang)
  local dir = WT.CACHE_DIR .. "/" .. lang
  return dir, dir .. "/text.lua", {
    normalFg = dir .. "/normal_fg.rgba", normalSh = dir .. "/normal_sh.rgba",
    smallFg = dir .. "/small_fg.rgba", smallSh = dir .. "/small_sh.rgba",
  }
end

local function loadCache(lang, stamp)
  local _, textPath, fontPaths = cachePaths(lang)
  local src = readFile(textPath)
  if not src then return nil end
  local chunk = load(src, "@" .. textPath, "t", {})
  if not chunk then return nil end
  local ok, data = pcall(chunk)
  if not (ok and type(data) == "table" and type(data.meta) == "table") then return nil end
  if data.meta.stamp ~= stamp then return nil end
  local font
  local mf = data.meta.font
  if type(mf) == "table" then
    font = {}
    for _, which in ipairs({ "normal", "small" }) do
      if mf[which] then
        local fg, sh = readFile(fontPaths[which .. "Fg"]), readFile(fontPaths[which .. "Sh"])
        if not (fg and sh) then return nil end
        font[which] = { fg = fg, sh = sh, widths = mf[which] }
      end
    end
  end
  return { lang = lang, entries = data.entries, font = font, meta = data.meta }
end

local function buildCache(lang, spec, romPath, stamp, recipeSrc)
  drawPreparing()
  local t0 = love.timer and love.timer.getTime() or os.clock()
  local rom = readFile(romPath)
  if not rom or #rom < 0x800000 then return nil, "cannot read " .. romPath end
  local code = headerCode(rom)
  if spec.code and code ~= spec.code then
    return nil, string.format("%s is %s, not %s", romPath, tostring(code), spec.code)
  end
  local recipe = parseRecipe(recipeSrc)
  local entries, stats = WT.decodeTexts(rom, recipe)
  local okF, font = pcall(WT.extractFonts, rom)
  if not okF or type(font) ~= "table" then
    if not okF then log("keeping the US font: " .. tostring(font)) end
    font = nil
  end
  rom = nil
  local meta = { stamp = stamp, lang = lang, stats = stats }
  local dir, textPath, fontPaths = cachePaths(lang)
  local f = fs()
  pcall(f.createDirectory, dir)
  local where = {}
  if font then
    meta.font = {}
    for _, which in ipairs({ "normal", "small" }) do
      local one = font[which]
      if one then
        meta.font[which] = one.widths
        f.write(fontPaths[which .. "Fg"], one.fg)
        f.write(fontPaths[which .. "Sh"], one.sh)
      end
      where[#where + 1] = which .. "=" .. (one and one.at or "US")
    end
  end
  f.write(textPath, serializeCache(meta, entries))
  local t1 = love.timer and love.timer.getTime() or os.clock()
  log(string.format("%s: built from %s in %.1fs: %d texts, %d rejected, font %s",
    lang, romPath, t1 - t0, stats.ok, stats.bad, #where > 0 and table.concat(where, " ") or "US"))
  collectgarbage()
  return { lang = lang, entries = entries, font = font, meta = meta }
end

-- Main entry (main.lua, WEAROS-PATCH): picks the watch language and gets
-- its texts ready before the game boots.  Quietly stays in English when the
-- language has no recipe or its ROM is not on the watch.
function WT.start(version)
  WT.active = nil
  if version and version ~= "firered" then return false end
  local lang = WatchText.lang()
  if lang == "en" then log("language en: original text") return false end
  local spec = WT.LANGS[lang]
  if not spec then log("language " .. lang .. ": no recipe yet, English text") return false end
  local recipePath = WT.RECIPE_DIR .. "/" .. spec.recipe
  local recipeSrc = readFile(recipePath)
  if not recipeSrc then log("language " .. lang .. ": " .. recipePath .. " missing") return false end
  local romPath, info = WT.findRom(spec)
  if not romPath then
    log(string.format("language %s: no ROM in %s/ (%s), English text", lang, WT.ROM_DIR, spec.roms[1]))
    return false
  end
  local stamp = table.concat({ WT.FORMAT, lang, #recipeSrc, romPath, info.size or 0, info.modtime or 0 }, ":")
  local active = loadCache(lang, stamp)
  if active then
    log(string.format("%s: %d texts from cache", lang, #active.entries))
  else
    local ok, built, why = pcall(buildCache, lang, spec, romPath, stamp, recipeSrc)
    if not ok or not built then
      log("language " .. lang .. " failed: " .. tostring(ok and why or built))
      return false
    end
    active = built
  end
  WT.active = active
  if active.font then WT.installFont(active.font) end
  -- a bundle loaded before this (it should not be) still gets the text
  local Space = package.loaded["src.core.game3.scripting.space"]
  if Space and Space.bundle then WT.patchBundle(Space.bundle) end
  return true
end

return WT
