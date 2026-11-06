import json, struct, collections, re, sys, time
exec(open("spike.py").read().split("t0 = time.time()")[0])   # reuse loaders + match()
CMDS = {int(k): v for k, v in json.load(open("cmds.json")).items()}
TB_WORDS = {0: 2, 1: 3, 2: 3, 3: 1, 4: 3, 5: 2, 6: 4, 7: 3, 8: 4}
GOTO, CALL, GOTO_IF, CALL_IF, END, RETURN = 5, 4, 6, 7, 2, 3

def isptr(v): return (v >> 24) in (8, 9) and (v & 0x1FFFFFF) < len(U)
pairs = collections.defaultdict(collections.Counter)
def pair(u, t):
    if isptr(u) and isptr(t): pairs[u & 0x1FFFFFF][t & 0x1FFFFFF] += 1; return True
    return False

seen = set()
def walk_script(us, ts, depth=0):
    stack = [(us, ts)]
    steps = 0
    while stack:
        u, t = stack.pop()
        while True:
            if (u, t) in seen or u >= len(U) - 8 or t >= len(T) - 8: break
            seen.add((u, t)); steps += 1
            op = U[u]
            if T[t] != op or op not in CMDS: break
            c = CMDS[op]
            if op == 0x5C:
                ty = U[u + 1]
                if T[t + 1] != ty or ty not in TB_WORDS: break
                p = 6
                for _ in range(TB_WORDS[ty]):
                    uv, tv = struct.unpack_from("<I", U, u + p)[0], struct.unpack_from("<I", T, t + p)[0]
                    pair(uv, tv)
                    if _ == TB_WORDS[ty] - 1 and ty in (1, 2, 6, 8) and isptr(uv) and isptr(tv):
                        stack.append((uv & 0x1FFFFFF, tv & 0x1FFFFFF))
                    p += 4
                u += p; t += p; continue
            size = c["size"]
            p = 1; mismatch = False
            dests = []
            for kind, name in c["args"]:
                if kind == "byte":
                    if name in ("condition", "type", "function", "destIndex") and U[u+p] != T[t+p]: mismatch = True
                    p += 1
                elif kind == "half": p += 2
                else:
                    uv, tv = struct.unpack_from("<I", U, u + p)[0], struct.unpack_from("<I", T, t + p)[0]
                    if pair(uv, tv) and name == "destination": dests.append((uv & 0x1FFFFFF, tv & 0x1FFFFFF))
                    p += 4
            if mismatch or p != size: break
            for d in dests: stack.append(d)
            if op in (END, RETURN, GOTO, 8) : break     # 8 = gotostd
            u += size; t += size
    return steps

def u32(b, o): return struct.unpack_from("<I", b, o)[0]
def off(v): return v & 0x1FFFFFF

# ---- gMapGroups in the target, by its literal-pool reference
G_U = 0x3526A8
ptr = struct.pack("<I", G_U | 0x08000000)
o = U.find(ptr); gT = None
while o != -1:
    r = match(o, 24, 12)
    if isinstance(r, int): gT = r; break
    o = U.find(ptr, o + 1)
print("gMapGroups USA %06X -> target %s" % (G_U, gT and "%06X" % gT))

groupsU = [off(u32(U, G_U + 4 * i)) for i in range(43)]
groupsT = [off(u32(T, gT + 4 * i)) for i in range(43)]
bounds = sorted(set(groupsU + [G_U]))
maps = 0
def walk_header(hu, ht):
    global maps
    maps += 1
    evU, evT = off(u32(U, hu + 4)), off(u32(T, ht + 4))
    msU, msT = u32(U, hu + 8), u32(T, ht + 8)
    if isptr(u32(U, hu + 4)) and isptr(u32(T, ht + 4)):
        n = [U[evU + k] for k in range(4)]
        if [T[evT + k] for k in range(4)] == n:
            objU, objT = off(u32(U, evU + 4)), off(u32(T, evT + 4))
            for i in range(n[0]):
                a, b = u32(U, objU + 24 * i + 16), u32(T, objT + 24 * i + 16)
                if pair(a, b): walk_script(off(a), off(b))
            coU, coT = off(u32(U, evU + 12)), off(u32(T, evT + 12))
            for i in range(n[2]):
                a, b = u32(U, coU + 16 * i + 12), u32(T, coT + 16 * i + 12)
                if pair(a, b): walk_script(off(a), off(b))
            bgU, bgT = off(u32(U, evU + 16)), off(u32(T, evT + 16))
            for i in range(n[3]):
                a, b = u32(U, bgU + 12 * i + 8), u32(T, bgT + 12 * i + 8)
                if U[bgU + 12 * i + 5] <= 4 and pair(a, b): walk_script(off(a), off(b))
    if isptr(msU) and isptr(msT):
        su, st = off(msU), off(msT)
        for _ in range(16):
            ty = U[su]
            if ty == 0 or T[st] != ty: break
            a, b = u32(U, su + 1), u32(T, st + 1)
            if ty in (2, 4) and pair(a, b):
                tu, tt = off(a), off(b)
                for _ in range(32):
                    if struct.unpack_from("<H", U, tu)[0] == 0: break
                    x, y = u32(U, tu + 4), u32(T, tt + 4)
                    if pair(x, y): walk_script(off(x), off(y))
                    tu += 8; tt += 8
            elif pair(a, b):
                walk_script(off(a), off(b))
            su += 5; st += 5

t0 = time.time()
for g in range(43):
    gu, gt = groupsU[g], groupsT[g]
    nxt = min([b for b in bounds if b > gu] or [gu + 4 * 64])
    count = (nxt - gu) // 4
    for i in range(count):
        a, b = u32(U, gu + 4 * i), u32(T, gt + 4 * i)
        if not (isptr(a) and isptr(b)): break
        walk_header(off(a), off(b))
print("maps walked:", maps, "script states:", len(seen), "pointer pairs:", len(pairs), "%.1fs" % (time.time() - t0))

# ---- results for the named texts
mapped, how = {}, collections.Counter()
for key, A in named.items():
    if A in pairs:
        tgt = pairs[A].most_common(1)[0][0]
        txt, ok = decode(T, tgt)
        if ok: mapped[key] = tgt; how["script walk"] += 1; continue
    how["unmapped"] += 1
print(dict(how))
json.dump({k: v for k, v in mapped.items()}, open("walk_%s.json" % target[:12].replace(" ", "_"), "w"))
import random; random.seed(5)
for key in random.sample(sorted(mapped), 6):
    print("--", key, "|", decode(U, named[key])[0][:60].replace("\n", " / "))
    print("   ->", decode(T, mapped[key])[0][:60].replace("\n", " / "))
