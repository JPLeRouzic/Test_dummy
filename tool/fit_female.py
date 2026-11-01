"""Completes the female body with bones and muscles fitted from the male body.

The HuBMAP female set (see build_models.py) has organs, spine, pelvis and legs,
but no skull, rib cage, arms, hands, feet and almost no muscles. This script
takes those parts from the male BodyParts3D body and bends them into the female
body:

  * the torso, head and legs follow a smooth thin-plate-spline warp that is
    pinned to matching landmarks in both bodies (vertebrae, hip, knee and ankle
    joints, eyes, heart, kidneys, bladder, lungs, the top of the head, toes and
    heels);
  * each arm follows its own upper arm, forearm and hand transform, because the
    female body holds its arms further out from the body than the male one;
    the female elbow, wrist and finger tips are read from the female skin.

Every added part is marked "fitted" in the manifest, so the app can say that it
was adapted from the male body.

Run after build_models.py and before repack_by_layer.py:

  python3 tool/fit_female.py pack/models
"""

import json
import os
import sys

import numpy as np

# Male parts that are copied into the female body, by key.
BONE_KEYS = {"skull", "teeth", "ribcage", "shoulder", "humerus", "forearm",
             "hand", "foot"}
MUSCLE_LAYER = "muscles"


class Model:
    def __init__(self, folder):
        self.dir = folder
        with open(os.path.join(folder, "manifest.json"), encoding="utf-8") as fh:
            self.man = json.load(fh)
        self.F = {name: i for i, name in enumerate(self.man["fields"])}
        self._bins = {}

    def f(self, row, name):
        return row[self.F[name]]

    def layer(self, row):
        return self.man["keys"][self.f(row, "key")]["layer"]

    def rows(self, test=lambda r: True):
        return [r for r in self.man["parts"] if test(r)]

    def _bin(self, ci):
        if ci not in self._bins:
            with open(os.path.join(self.dir, self.man["chunks"][ci]), "rb") as fh:
                self._bins[ci] = fh.read()
        return self._bins[ci]

    def geom(self, row):
        data = self._bin(self.f(row, "chunk"))
        vc, ic = self.f(row, "vertexCount"), self.f(row, "indexCount")
        pos = np.frombuffer(data, np.float32, vc * 3, self.f(row, "positions"))
        idx = np.frombuffer(data, np.uint32, ic, self.f(row, "indices"))
        return pos.reshape(-1, 3).astype(np.float64), idx.copy()

    def pts(self, test):
        ps = [self.geom(r)[0] for r in self.rows(test)]
        return np.concatenate(ps) if ps else np.zeros((0, 3))

    def named(self, *names):
        low = {n.lower() for n in names}
        return lambda r: self.f(r, "name").lower() in low

    def key(self, key, extra=lambda r: True):
        return lambda r: self.f(r, "key") == key and extra(r)


def top(p, d):
    return p[p[:, 1] > p[:, 1].max() - d]


def bottom(p, d):
    return p[p[:, 1] < p[:, 1].min() + d]


def box_center(p):
    return (p.min(0) + p.max(0)) / 2


def on_side(p, s):
    return p[p[:, 0] * s > 0]


# ---------------------------------------------------------------- landmarks

def leg_joints(m, side):
    femur = m.pts(m.named(f"{side} femur"))
    tibia = m.pts(m.named(f"{side} tibia"))
    fibula = m.pts(m.named(f"{side} fibula"))
    head = top(femur, 0.05)
    medial = head[np.abs(head[:, 0]) < np.median(np.abs(head[:, 0]))]
    hip = top(medial, 0.04).mean(0)
    knee = bottom(femur, 0.03).mean(0)
    ankle = (bottom(tibia, 0.015).mean(0) + bottom(fibula, 0.015).mean(0)) / 2
    return hip, knee, ankle


def hip_bone(m, side, s):
    if m.man["sex"] == "male":
        bone = m.pts(m.named(f"{side} hip bone"))
    else:
        bone = on_side(m.pts(m.key("pelvis")), s)
    femur = m.pts(m.named(f"{side} femur"))
    head = top(femur, 0.08)
    return [
        bone[np.argmax(bone[:, 0] * s)],   # widest point of the iliac crest
        bone[np.argmax(bone[:, 1])],       # top of the iliac crest
        bone[np.argmin(bone[:, 1])],       # ischial tuberosity
        bone[np.argmax(bone[:, 2])],       # front of the pelvis
        head[np.argmax(head[:, 0] * s)],   # greater trochanter
    ]


def spine_points(m, names):
    return [box_center(m.pts(m.named(n))) for n in names]


def organ_points(m):
    eyes = m.pts(m.key("eyes"))
    kidney = m.pts(lambda r: m.f(r, "key") == "kidneys"
                   and "ureter" not in m.f(r, "name").lower())
    return [
        on_side(eyes, 1).mean(0), on_side(eyes, -1).mean(0),
        m.pts(m.key("heart")).mean(0),
        on_side(kidney, 1).mean(0), on_side(kidney, -1).mean(0),
        m.pts(m.key("bladder")).mean(0),
    ]


def male_arm(m, side):
    s = 1 if side == "left" else -1
    humerus = m.pts(m.named(f"{side} humerus"))
    radius = m.pts(m.named(f"{side} radius"))
    ulna = m.pts(m.named(f"{side} ulna"))
    hand = on_side(m.pts(m.key("hand")), s)
    head = top(humerus, 0.04)
    shoulder = head[np.abs(head[:, 0]) < np.median(np.abs(head[:, 0]))].mean(0)
    elbow = bottom(humerus, 0.02).mean(0)
    wrist = (bottom(radius, 0.015).mean(0) + bottom(ulna, 0.015).mean(0)) / 2
    tip = bottom(hand, 0.01).mean(0)
    return shoulder, elbow, wrist, tip


def skin_arm_line(skin, s):
    """Centre of the female arm in thin slices, from the armpit to the hand."""
    out = []
    for y in np.arange(0.74, 1.17, 0.01):
        sl = skin[np.abs(skin[:, 1] - y) < 0.005]
        sl = sl[sl[:, 0] * s > 0.15]
        if len(sl) < 8:
            continue
        xs = np.sort(sl[:, 0] * s)
        gaps = np.where(np.diff(xs) > 0.02)[0]
        start = xs[gaps[-1] + 1] if len(gaps) else xs[0]
        arm = sl[sl[:, 0] * s >= start - 1e-9]
        if len(arm) < 8:
            continue
        out.append((y, arm.mean(0), np.ptp(arm[:, 0]), np.ptp(arm[:, 2])))
    return out


def female_arm(skin, s, upper_len, fore_len):
    line = skin_arm_line(skin, s)
    pts = np.array([c for _, c, _, _ in line])
    width = np.array([wx + wz for _, _, wx, wz in line])
    ys = np.array([y for y, _, _, _ in line])
    # wrist: the narrowest slice between the hand and the elbow
    band = (ys > 0.86) & (ys < 1.0)
    wrist = pts[band][np.argmin(width[band])]
    tip_slice = skin[(skin[:, 0] * s > 0.3)]
    tip = bottom(tip_slice, 0.012).mean(0)
    # elbow: walk up the centre line by the forearm length
    above = pts[pts[:, 1] > wrist[1]]
    d = np.linalg.norm(above - wrist, axis=1)
    elbow = above[np.argmin(np.abs(d - fore_len))]
    # shoulder: continue in the same direction as the upper part of the
    # arm line for the length of the upper arm
    upper = pts[pts[:, 1] > elbow[1] - 0.02]
    direction = upper[-1] - upper[0]
    direction /= np.linalg.norm(direction)
    shoulder = elbow + direction * upper_len
    return shoulder, elbow, wrist, tip


def female_feet(skin, s):
    foot = skin[(skin[:, 1] < 0.06) & (skin[:, 0] * s > 0.02)]
    toe = foot[np.argmax(foot[:, 2])].copy()
    heel = foot[np.argmin(foot[:, 2])].copy()
    toe[2] -= 0.012
    toe[1] = 0.02
    heel[2] += 0.012
    heel[1] = 0.03
    return toe, heel


def male_feet(m, s):
    foot = on_side(m.pts(m.key("foot")), s)
    toe = foot[np.argmax(foot[:, 2])].copy()
    heel = foot[np.argmin(foot[:, 2])].copy()
    toe[1] = 0.02
    heel[1] = 0.03
    return toe, heel


# ---------------------------------------------------------------- warps

class ThinPlate:
    """3D thin-plate spline that sends src landmarks exactly onto dst."""

    def __init__(self, src, dst):
        src, dst = np.asarray(src, float), np.asarray(dst, float)
        n = len(src)
        k = self._kernel(src, src)
        p = np.hstack([np.ones((n, 1)), src])
        a = np.zeros((n + 4, n + 4))
        a[:n, :n] = k + np.eye(n) * 1e-6
        a[:n, n:] = p
        a[n:, :n] = p.T
        b = np.zeros((n + 4, 3))
        b[:n] = dst
        self.w = np.linalg.solve(a, b)
        self.src = src

    @staticmethod
    def _kernel(a, b):
        d = np.linalg.norm(a[:, None, :] - b[None, :, :], axis=2)
        return d  # r is the biharmonic kernel in 3D

    def __call__(self, x):
        out = np.empty_like(x)
        n = len(self.src)
        for i in range(0, len(x), 200000):
            xs = x[i:i + 200000]
            k = self._kernel(xs, self.src)
            p = np.hstack([np.ones((len(xs), 1)), xs])
            out[i:i + 200000] = k @ self.w[:n] + p @ self.w[n:]
        return out


def rotation_between(a, b):
    a = a / np.linalg.norm(a)
    b = b / np.linalg.norm(b)
    v = np.cross(a, b)
    c = float(np.dot(a, b))
    if np.linalg.norm(v) < 1e-9:
        return np.eye(3)
    vx = np.array([[0, -v[2], v[1]], [v[2], 0, -v[0]], [-v[1], v[0], 0]])
    return np.eye(3) + vx + vx @ vx * (1 / (1 + c))


class Segment:
    """Moves a limb segment from male joints (a, b) onto female joints (a2, b2)."""

    def __init__(self, a, b, a2, b2, radial):
        self.a, self.a2 = a, a2
        self.r = rotation_between(b - a, b2 - a2)
        self.axis = (b - a) / np.linalg.norm(b - a)
        self.along = np.linalg.norm(b2 - a2) / np.linalg.norm(b - a)
        self.radial = radial

    def __call__(self, x):
        v = x - self.a
        t = v @ self.axis
        par = np.outer(t, self.axis)
        v2 = par * self.along + (v - par) * self.radial
        return v2 @ self.r.T + self.a2


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0, 1)
    return t * t * (3 - 2 * t)


class Arm:
    def __init__(self, male, female, radial):
        s, e, w, t = male
        s2, e2, w2, t2 = female
        self.male = male
        self.segs = [Segment(s, e, s2, e2, radial), Segment(e, w, e2, w2, radial),
                     Segment(w, t, w2, t2, radial)]

    def weights(self, x):
        """Weight of the arm (vs. the torso) and position along the arm (0..3)."""
        s, e, w, t = self.male
        best = np.full(len(x), np.inf)
        chain = np.zeros(len(x))
        for i, (a, b) in enumerate(((s, e), (e, w), (w, t))):
            seg = b - a
            raw = (x - a) @ seg / (seg @ seg)
            tt = np.clip(raw, 0, 1)
            dist = np.linalg.norm(x - (a + np.outer(tt, seg)), axis=1)
            if i == 0:
                # above the shoulder joint the torso takes over quickly
                dist = dist + np.maximum(0, -raw) * np.linalg.norm(seg) * 2
            closer = dist < best
            best = np.where(closer, dist, best)
            chain = np.where(closer, i + tt, chain)
        arm = 1 - smoothstep(0.04, 0.065, best)
        return arm, chain

    def __call__(self, x, chain):
        out = np.zeros_like(x)
        w_elbow = smoothstep(0.9, 1.1, chain)
        w_wrist = smoothstep(1.92, 2.05, chain)
        p0, p1, p2 = (seg(x) for seg in self.segs)
        upper = p0 * (1 - w_elbow)[:, None] + p1 * w_elbow[:, None]
        out = upper * (1 - w_wrist)[:, None] + p2 * w_wrist[:, None]
        return out


# ---------------------------------------------------------------- build

def vertex_normals(pos, idx):
    tri = idx.reshape(-1, 3)
    a, b, c = pos[tri[:, 0]], pos[tri[:, 1]], pos[tri[:, 2]]
    fn = np.cross(b - a, c - a)
    n = np.zeros_like(pos)
    for k in range(3):
        np.add.at(n, tri[:, k], fn)
    length = np.linalg.norm(n, axis=1, keepdims=True)
    length[length == 0] = 1
    n /= length
    return np.round(n * 32767).astype(np.int16)


def fit(models_dir):
    male = Model(os.path.join(models_dir, "male"))
    female = Model(os.path.join(models_dir, "female"))
    out_dir = female.dir

    src, dst = [], []

    def pin(a, b):
        src.append(np.asarray(a, float))
        dst.append(np.asarray(b, float))

    for a, b in zip(spine_points(male, ["Axis", "First thoracic vertebra", "Sixth thoracic vertebra",
                                        "Twelfth thoracic vertebra", "Third lumbar vertebra",
                                        "Fifth lumbar vertebra", "Sacrum"]),
                    spine_points(female, ["vertebral bone 2", "thoracic vertebra 1", "thoracic vertebra 6",
                                          "thoracic vertebra 12", "lumbar vertebra 3",
                                          "lumbar vertebra 5", "fused sacrum"])):
        pin(a, b)
    for side in ("left", "right"):
        for a, b in zip(leg_joints(male, side), leg_joints(female, side)):
            pin(a, b)
        hm, km, am = leg_joints(male, side)
        hf, kf, af = leg_joints(female, side)
        pin((hm + km) / 2, (hf + kf) / 2)
        pin((km + am) / 2, (kf + af) / 2)
        s = 1 if side == "left" else -1
        for a, b in zip(hip_bone(male, side, s), hip_bone(female, side, s)):
            pin(a, b)
    for a, b in zip(organ_points(male), organ_points(female)):
        pin(a, b)

    # The male lungs were fitted from the female lung segments box to box, so
    # the corners of those two boxes are matching points of the chest.
    ml = male.pts(lambda r: male.f(r, "key") == "lungs" and male.f(r, "fitted") == 1)
    fl = female.pts(lambda r: "bronchopulmonary segment" in female.f(r, "name").lower())
    for cx in (0, 1):
        for cy in (0, 1):
            for cz in (0, 1):
                pick = np.array([cx, cy, cz])
                pin(np.where(pick, ml.max(0), ml.min(0)), np.where(pick, fl.max(0), fl.min(0)))

    m_skin = male.pts(lambda r: male.layer(r) == "skin")
    f_skin = female.pts(lambda r: female.layer(r) == "skin")
    pin(top(m_skin, 0.01).mean(0) * [1, 0, 1] + [0, m_skin[:, 1].max() - 0.008, 0],
        top(f_skin, 0.01).mean(0) * [1, 0, 1] + [0, f_skin[:, 1].max() - 0.008, 0])
    for s in (1, -1):
        for a, b in zip(male_feet(male, s), female_feet(f_skin, s)):
            pin(a, b)

    # Arms.
    arms = {}
    tps_core = ThinPlate(src, dst)
    for side, s in (("left", 1), ("right", -1)):
        m_arm = male_arm(male, side)
        shoulder_f = tps_core(m_arm[0][None])[0]
        upper_len = np.linalg.norm(m_arm[1] - m_arm[0]) * 0.95
        fore_len = np.linalg.norm(m_arm[2] - m_arm[1]) * 0.95
        f_arm = list(female_arm(f_skin, s, upper_len, fore_len))
        f_arm[0] = shoulder_f
        arms[side] = Arm(m_arm, f_arm, 0.93)
        print(side, "arm male", np.round(m_arm, 3).tolist())
        print(side, "arm female", np.round(f_arm, 3).tolist())
        # pin the shoulder joint in the torso warp as well
        pin(m_arm[0], shoulder_f)
    tps = ThinPlate(src, dst)

    def warp(pos):
        out = tps(pos)
        for side in ("left", "right"):
            arm = arms[side]
            w, chain = arm.weights(pos)
            hit = w > 0
            if hit.any():
                moved = arm(pos[hit], chain[hit])
                out[hit] = out[hit] * (1 - w[hit])[:, None] + moved * w[hit][:, None]
        return out

    # Drop parts from an earlier run and the few female muscles (the fitted
    # male muscles replace them).
    rows = [r for r in female.man["parts"]
            if not str(female.f(r, "id")).startswith("M-")
            and female.layer(r) != MUSCLE_LAYER]

    take = male.rows(lambda r: (male.f(r, "key") in BONE_KEYS or male.layer(r) == MUSCLE_LAYER)
                     and male.f(r, "fitted") == 0)
    chunks = list(female.man["chunks"])
    name = "fitted-0.bin"
    n = 0
    while name in chunks:
        n += 1
        name = f"fitted-{n}.bin"
    chunks.append(name)
    ci = len(chunks) - 1
    buf = bytearray()
    keys = dict(female.man["keys"])
    for r in take:
        pos, idx = male.geom(r)
        pos2 = warp(pos)
        nrm = vertex_normals(pos2, idx)
        while len(buf) % 4:
            buf.append(0)
        po = len(buf)
        buf.extend(pos2.astype(np.float32).tobytes())
        no = len(buf)
        buf.extend(nrm.tobytes())
        while len(buf) % 4:
            buf.append(0)
        io = len(buf)
        buf.extend(idx.astype(np.uint32).tobytes())
        lo, hi = pos2.min(0), pos2.max(0)
        row = [None] * len(female.man["fields"])
        values = {
            "id": "M-" + str(male.f(r, "id")), "name": male.f(r, "name"), "key": male.f(r, "key"),
            "side": male.f(r, "side"), "chunk": ci, "positions": po, "normals": no, "indices": io,
            "vertexCount": len(pos2), "indexCount": len(idx),
            "minX": round(float(lo[0]), 5), "minY": round(float(lo[1]), 5), "minZ": round(float(lo[2]), 5),
            "maxX": round(float(hi[0]), 5), "maxY": round(float(hi[1]), 5), "maxZ": round(float(hi[2]), 5),
            "fitted": 1,
        }
        for k, v in values.items():
            row[female.F[k]] = v
        rows.append(row)
        keys.setdefault(male.f(r, "key"), male.man["keys"][male.f(r, "key")])
    with open(os.path.join(out_dir, name), "wb") as fh:
        fh.write(buf)

    used = {female.f(r, "key") for r in rows}
    female.man["keys"] = {k: v for k, v in keys.items() if k in used}
    female.man["chunks"] = chunks
    female.man["parts"] = rows
    female.man.pop("chunkLayers", None)
    lo = np.array([[r[female.F["minX"]], r[female.F["minY"]], r[female.F["minZ"]]] for r in rows]).min(0)
    hi = np.array([[r[female.F["maxX"]], r[female.F["maxY"]], r[female.F["maxZ"]]] for r in rows]).max(0)
    female.man["bounds"] = [lo.round(4).tolist(), hi.round(4).tolist()]
    with open(os.path.join(out_dir, "manifest.json"), "w", encoding="utf-8") as fh:
        json.dump(female.man, fh, separators=(",", ":"), ensure_ascii=False)
    print("female: added", len(take), "fitted parts,", len(buf) // 1024, "KB")


if __name__ == "__main__":
    fit(sys.argv[1])
