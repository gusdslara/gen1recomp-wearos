import json, struct, collections, re, sys, time
exec(open("walk.py").read().split("# ---- results for the named texts")[0])
TT0 = time.time()
# Pass A results (code literal pools): pair every named text directly
codeHits = 0
for key, A in named.items():
    ptr = struct.pack("<I", A | 0x08000000)
    occ, p = [], U.find(ptr)
    while p != -1 and len(occ) < 6:
        occ.append(p); p = U.find(ptr, p + 1)
    for o in occ:
        for L, Rn in ((12, 8), (24, 12), (40, 20), (64, 32)):
            r = match(o, L, Rn)
            if r == "multi": continue
            if isinstance(r, int): pairs[A][r] += 2; codeHits += 1
            break
print("pass A hits", codeHits)

# index of every aligned pointer cell in both ROMs: value -> [cell offsets]
def cells(B):
    idx = collections.defaultdict(list)
    mv = memoryview(B)
    for o in range(0, len(B) - 3, 4):
        if B[o + 3] in (8, 9):
            idx[struct.unpack_from("<I", B, o)[0] & 0x1FFFFFF].append(o)
    return idx
cU, cT = cells(U), cells(T)
print("cells indexed %.1fs" % (time.time() - TT0))

def isp(B, o): return 0 <= o < len(B) - 3 and B[o + 3] in (8, 9)
aligned = set()
def align(cu, ct):
    """two cells known to correspond: pair the pointer runs around them"""
    if (cu, ct) in aligned: return 0
    aligned.add((cu, ct))
    n = 0
    for step in (4, -4):
        k = 0; miss = 0
        while miss < 3 and k < 4096:
            a, b = cu + k, ct + k
            if isp(U, a) and isp(T, b):
                pairs[u32(U, a) & 0x1FFFFFF][u32(T, b) & 0x1FFFFFF] += 1; n += 1; miss = 0
            else:
                miss += 1
            k += step
    return n

changed, rounds = True, 0
while changed and rounds < 8:
    changed, rounds = False, rounds + 1
    before = len(pairs)
    for A, ctr in list(pairs.items()):
        B = ctr.most_common(1)[0][0]
        lu, lt = cU.get(A, []), cT.get(B, [])
        if 1 <= len(lu) <= 4 and len(lu) == len(lt):
            for cu, ct in zip(lu, lt):
                align(cu, ct)
    if len(pairs) > before: changed = True
    print("round", rounds, "pairs", len(pairs))

mapped, how = {}, collections.Counter()
for key, A in named.items():
    if A in pairs:
        tgt = pairs[A].most_common(1)[0][0]
        if decode(T, tgt)[1]: mapped[key] = tgt; how["mapped"] += 1; continue
        how["bad decode"] += 1; continue
    how["unmapped"] += 1
print(dict(how), "%.1fs" % (time.time() - TT0))
json.dump(mapped, open("recipe_%s.json" % target.split("(")[-1][:6].strip(")"), "w"), indent=0)
import random; random.seed(11)
for key in random.sample(sorted(mapped), 8):
    print("--", key, "|", decode(U, named[key])[0][:55].replace("\n", " / "))
    print("   ->", decode(T, mapped[key])[0][:55].replace("\n", " / "))
