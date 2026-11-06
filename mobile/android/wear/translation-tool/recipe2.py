import json, struct, collections, re, sys, time
exec(open("recipe.py").read().split("mapped, how = {}, collections.Counter()")[0])
T1 = time.time()
def word(B, o): return struct.unpack_from("<I", B, o)[0]
def same_kind(a, b):
    ha, hb = a >> 24, b >> 24
    if a == b: return True
    if ha == hb and ha in (2, 3, 4): return True       # RAM / IO addresses
    if a < 0x10000 and b < 0x10000: return True         # small constants
    return False
aligned2 = set()
def align2(cu, ct, limit=2048):
    if (cu, ct) in aligned2: return 0
    aligned2.add((cu, ct)); n = 0
    for step in (4, -4):
        k, bad = 0, 0
        while bad < 3 and abs(k) < limit:
            a, b = cu + k, ct + k
            if a < 0 or b < 0 or a > len(U) - 4 or b > len(T) - 4: break
            if isp(U, a) and isp(T, b):
                pairs[word(U, a) & 0x1FFFFFF][word(T, b) & 0x1FFFFFF] += 1; n += 1; bad = 0
            elif isp(U, a) != isp(T, b): bad += 1
            elif not same_kind(word(U, a), word(T, b)): bad += 0.5
            k += step
    return n

# (b) table / struct bases referenced from anywhere: map the base, align from it
starts = []
o = 0
while o < len(U) - 8:
    if isp(U, o) and not isp(U, o - 4) and (isp(U, o + 4) or isp(U, o + 8)):
        starts.append(o)
    o += 4
print("candidate tables:", len(starts))
seeded = 0
for S in starts:
    refs = cU.get(S, [])
    if not refs or len(refs) > 6: continue
    for r in refs:
        hit = None
        for L, Rn in ((12, 8), (24, 12), (40, 20)):
            m = match(r, L, Rn)
            if m == "multi": continue
            if isinstance(m, int): hit = m
            break
        if hit is not None:
            seeded += align2(S, hit); break
print("seeded from table bases:", seeded, "%.0fs" % (time.time() - T1))
# (a) re-run neighbour alignment with the tolerant aligner, to a fixpoint
for rnd in range(6):
    before = len(pairs)
    for A, ctr in list(pairs.items()):
        B = ctr.most_common(1)[0][0]
        lu, lt = cU.get(A, []), cT.get(B, [])
        if 1 <= len(lu) <= 6 and len(lu) == len(lt):
            for cu, ct in zip(lu, lt): align2(cu, ct)
    # (c) anything paired that lands on a script in both ROMs: walk it
    for A, ctr in list(pairs.items()):
        B = ctr.most_common(1)[0][0]
        if 0x150000 <= A < 0x1E0000 and U[A] in CMDS and T[B] == U[A]:
            walk_script(A, B)
    print("round", rnd, "pairs", len(pairs))
    if len(pairs) == before: break

mapped, how = {}, collections.Counter()
for key, A in named.items():
    if A in pairs:
        tgt = pairs[A].most_common(1)[0][0]
        if decode(T, tgt)[1]: mapped[key] = tgt; how["mapped"] += 1; continue
        how["bad decode"] += 1; continue
    how["unmapped"] += 1
print(dict(how), "%.0fs" % (time.time() - TT0))
json.dump(mapped, open("recipe2_%s.json" % target.split("(")[-1][:6].strip(")"), "w"), indent=0)
