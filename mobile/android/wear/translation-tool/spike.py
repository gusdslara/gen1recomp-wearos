import re, struct, sys, collections, time
R = "/mnt/user-data/uploads/Pokemon - FireRed Version (USA)/"
U = open(R + "Pokemon - FireRed Version (USA).gba", "rb").read()
target = sys.argv[1] if len(sys.argv) > 1 else "Pokemon - Version Rouge Feu (France).gba"
T = open(R + target, "rb").read()
src = open("/mnt/user-data/uploads/wearOS ports/gen1recomp/src/import/gba/versions_text.lua", encoding="utf-8").read()
named = {}
block = src.split("NAMED_TEXTS = {", 1)[1].split("\n  },", 1)[0]
for k, v in re.findall(r"(\w+) = 0x([0-9A-Fa-f]+)", block):
    named[k] = int(v, 16)
print("named texts:", len(named))

# gen3 charmap (enough to eyeball)
CH = {0: " "}
for i, c in enumerate("0123456789!?.-"): pass
for i in range(26): CH[0xBB + i] = chr(65 + i); CH[0xD5 + i] = chr(97 + i)
for i in range(10): CH[0xA1 + i] = str(i)
CH.update({0xAB: "!", 0xAC: "?", 0xAD: ".", 0xAE: "-", 0xB0: "…", 0xB1: "“", 0xB2: "”", 0xB3: "‘", 0xB4: "'", 0xB8: ",", 0xBA: "/", 0xFE: "\n", 0xFA: "\n", 0xFB: "\n\n", 0x1B: "é"})
ACC = {0x01:"À",0x02:"Á",0x03:"Â",0x04:"Ç",0x05:"È",0x06:"É",0x07:"Ê",0x08:"Ë",0x09:"Ì",0x0B:"Î",0x0C:"Ï",0x0D:"Ò",0x0E:"Ó",0x0F:"Ô",0x10:"Œ",0x11:"Ù",0x12:"Ú",0x13:"Û",0x14:"Ñ",0x15:"ß",0x16:"à",0x17:"á",0x19:"ç",0x1A:"è",0x1B:"é",0x1C:"ê",0x1D:"ë",0x1E:"ì",0x20:"î",0x21:"ï",0x22:"ò",0x23:"ó",0x24:"ô",0x25:"œ",0x26:"ù",0x27:"ú",0x28:"û",0x29:"ñ",0x2A:"º",0x2B:"ª",0x2D:"&",0x34:"Lv",0x35:"=",0x36:";",0x51:"¿",0x52:"¡",0x5A:"Í",0x5B:"%",0x5C:"(",0x5D:")",0x68:"â",0x6F:"í"}
CH.update(ACC)
def decode(buf, off, maxlen=400):
    out = []
    i = off
    while i < len(buf) and i - off < maxlen:
        b = buf[i]
        if b == 0xFF: return "".join(out), True
        if b == 0xFD: out.append("{V%d}" % buf[i+1]); i += 2; continue
        if b == 0xFC: out.append("{C}"); i += 2; continue
        out.append(CH.get(b, "·")); i += 1
    return "".join(out), False

def is_ptr_at(buf, i):
    return i + 3 < len(buf) and buf[i+3] in (0x08, 0x09) and buf[i+2] <= 0xFF

def masked(ctx):
    m = [True] * len(ctx)
    for i in range(len(ctx) - 3):
        if ctx[i+3] in (0x08, 0x09):
            for j in range(i, i + 4): m[j] = False
    return m

def longest_run(ctx, m):
    best, cur, start, bs = 0, 0, 0, 0
    for i, ok in enumerate(m + [False]):
        if ok:
            if cur == 0: start = i
            cur += 1
            if cur > best: best, bs = cur, start
        else: cur = 0
    return bs, best

def match(o, L, Rn):
    lo, hi = o - L, o + 4 + Rn
    if lo < 0 or hi > len(U): return None
    ctx = U[lo:hi]
    m = masked(ctx)
    for j in range(L, L + 4): m[j] = False  # the pointer itself
    bs, bl = longest_run(ctx, m)
    if bl < 6: return None
    anchor = ctx[bs:bs + bl]
    hits = []
    p = T.find(anchor)
    while p != -1:
        s0 = p - bs
        if s0 >= 0 and s0 + len(ctx) <= len(T):
            cand = T[s0:s0 + len(ctx)]
            if all((not m[k]) or cand[k] == ctx[k] for k in range(len(ctx))) and cand[L+3] in (0x08, 0x09):
                hits.append(s0)
                if len(hits) > 1: return "multi"
        p = T.find(anchor, p + 1)
    if len(hits) == 1:
        s0 = hits[0]
        return struct.unpack_from("<I", T, s0 + L)[0] & 0x01FFFFFF
    return None

t0 = time.time()
result, how = {}, collections.Counter()
for key, A in named.items():
    ptr = struct.pack("<I", A | 0x08000000)
    occ, p = [], U.find(ptr)
    while p != -1 and len(occ) < 6:
        occ.append(p); p = U.find(ptr, p + 1)
    if not occ: how["no pointer in USA"] += 1; continue
    votes = collections.Counter()
    for o in occ:
        for L, Rn in ((12, 8), (24, 12), (40, 20), (64, 32)):
            r = match(o, L, Rn)
            if r == "multi": continue
            if r is not None: votes[r] += 1
            break
    if votes:
        addr, _ = votes.most_common(1)[0]
        txt, ok = decode(T, addr)
        if ok: result[key] = addr; how["mapped"] += 1
        else: how["bad decode"] += 1
    else: how["no unique context"] += 1
print(dict(how), "in %.1fs" % (time.time() - t0))
import random
random.seed(3)
for key in random.sample(sorted(result), 8):
    print("--", key, "USA:", decode(U, named[key])[0][:70].replace("\n", " / "))
    print("   ->", decode(T, result[key])[0][:70].replace("\n", " / "))
