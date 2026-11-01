"""Builds the 3D body data that Anatomo ships in assets/models/.

Sources (both CC BY 4.0, see ATTRIBUTION.md):
  * Male:   BodyParts3D 4.0, as simplified and packed by the open-source
            "human-atlas" project (github.com/ashemag/human-atlas, MIT).
  * Female: HuBMAP 3D Reference Organ Set for Female v1.5, packed the same way
            in an earlier revision of that project (commit d72b4f6).

What this script adds:
  * every part gets an Anatomo "key" (heart, liver, femur, ...) that links it to
    the texts in assets/content/<language>.json, and a layer (organs, bones,
    muscles, nerves, vessels, skin);
  * BodyParts3D has no solid lung or liver tissue, so the female lung segments
    and liver are fitted into the male body (marked "fitted" in the manifest).

Usage:
  python3 tool/build_models.py <human-atlas checkout> <female data dir> <out dir>
"""

import json
import os
import shutil
import struct
import sys

import numpy as np

HEAD_Y = {"male": 1.47, "female": 1.43}

LAYER = {
    # organs
    "brain": "organs", "eyes": "organs", "ears": "organs", "nose": "organs",
    "tongue": "organs", "salivary": "organs", "pituitary": "organs",
    "adrenals": "organs", "throat": "organs", "larynx": "organs",
    "trachea": "organs", "lungs": "organs", "diaphragm": "organs",
    "heart": "organs", "esophagus": "organs", "stomach": "organs",
    "liver": "organs", "gallbladder": "organs", "pancreas": "organs",
    "spleen": "organs", "thymus": "organs", "small_intestine": "organs",
    "large_intestine": "organs", "kidneys": "organs", "bladder": "organs",
    "testes": "organs", "prostate": "organs", "penis": "organs",
    "uterus": "organs", "ovaries": "organs", "fallopian_tubes": "organs",
    "vagina": "organs", "breasts": "organs",
    # bones
    "skull": "bones", "teeth": "bones", "spine": "bones", "ribcage": "bones",
    "shoulder": "bones", "humerus": "bones", "forearm": "bones",
    "hand": "bones", "pelvis": "bones", "femur": "bones", "knee": "bones",
    "lower_leg": "bones", "foot": "bones", "bones": "bones",
    # muscles
    "muscles": "muscles", "biceps": "muscles", "triceps": "muscles",
    "deltoid": "muscles", "chest_muscles": "muscles", "abs": "muscles",
    "back_muscles": "muscles", "glutes": "muscles", "quadriceps": "muscles",
    "hamstrings": "muscles", "calf": "muscles", "connective": "muscles",
    # nerves
    "spinal_cord": "nerves", "nerves": "nerves",
    # vessels
    "aorta": "vessels", "arteries": "vessels", "veins": "vessels",
    "lymph": "vessels",
    # skin
    "skin": "skin",
}

# Keys where tapping one piece selects only that piece (there are hundreds).
SINGLE = {"muscles", "connective", "arteries", "veins", "nerves", "bones", "lymph"}

COLOR = {
    "brain": "#D9A3A6", "eyes": "#D9DDE2", "ears": "#D5A88E", "nose": "#D8B0A0",
    "tongue": "#C9646A", "salivary": "#D9B38E", "pituitary": "#C98C7E",
    "adrenals": "#D9A44E", "throat": "#B9757A", "larynx": "#D8C9B4",
    "trachea": "#E2C4B6", "lungs": "#D8857D", "diaphragm": "#A85B50",
    "heart": "#B8343B", "esophagus": "#C9867A", "stomach": "#D98F72",
    "liver": "#7E2E27", "gallbladder": "#5E8A3A", "pancreas": "#E0B56E",
    "spleen": "#6E3352", "thymus": "#D8B4A6", "small_intestine": "#E0A190",
    "large_intestine": "#C9856A", "kidneys": "#9A3C40", "bladder": "#D3A07A",
    "testes": "#D8B2A0", "prostate": "#C99088", "penis": "#C98F80",
    "uterus": "#C97C86", "ovaries": "#D9A2A0", "fallopian_tubes": "#D69A96",
    "vagina": "#C9848C", "breasts": "#E2B8A4",
    "skull": "#E6DCC5", "teeth": "#F2EEE2", "spine": "#E1D6BE",
    "ribcage": "#E4D9C3", "shoulder": "#E4D9C3", "humerus": "#E4D9C3",
    "forearm": "#E4D9C3", "hand": "#E4D9C3", "pelvis": "#E1D5BC",
    "femur": "#E4D9C3", "knee": "#DCD3C0", "lower_leg": "#E4D9C3",
    "foot": "#E4D9C3", "bones": "#E4D9C3",
    "muscles": "#A85B50", "biceps": "#B0594C", "triceps": "#A55248",
    "deltoid": "#B0594C", "chest_muscles": "#AE564A", "abs": "#B25D50",
    "back_muscles": "#A35047", "glutes": "#A85B50", "quadriceps": "#B0594C",
    "hamstrings": "#A55248", "calf": "#AE564A", "connective": "#C8D6CF",
    "spinal_cord": "#E3C27A", "nerves": "#E0BF6A",
    "aorta": "#C8453F", "arteries": "#C0453C", "veins": "#4E74A8",
    "lymph": "#8FB07E", "skin": "#D4A88A",
}

SKULL = ("frontal bone", "parietal bone", "temporal bone", "occipital bone",
         "sphenoid", "ethmoid", "maxilla", "mandible", "zygomatic",
         "nasal bone", "palatine bone", "vomer", "lacrimal bone", "hyoid")
CARPAL = ("scaphoid", "lunate", "triquetral", "pisiform", "trapezium",
          "trapezoid", "capitate", "hamate", "metacarpal")
TARSAL = ("calcaneus", "talus", "navicular", "cuboid", "cuneiform bone",
          "metatarsal")


def classify(name, system, cy, sex):
    n = name.lower()

    def has(*words):
        return any(w in n for w in words)

    head = cy > HEAD_Y[sex]

    if system == "pregnancy":
        return None
    if system == "integumentary":
        if has("mammary", "breast", "nipple", "areola", "lactiferous"):
            return "breasts"
        return "skin"
    if has("lateral ventricle", "third ventricle", "fourth ventricle",
           "interventricular foramen", "aqueduct", "choroid plexus"):
        return "brain"
    if system == "reproductive":
        if sex == "male":
            if has("testis", "epididym"):
                return "testes"
            if has("penis", "glans"):
                return "penis"
            return "prostate"
        if has("ovar", "mesovarium"):
            return "ovaries"
        if has("uterine tube", "salpinx"):
            return "fallopian_tubes"
        if has("vagina", "cervicovaginal"):
            return "vagina"
        return "uterus"
    if system == "cardiac":
        if has("aorta", "brachiocephalic", "carotid", "subclavian"):
            return "aorta"
        return "heart"
    if system == "endocrine":
        if has("adrenal"):
            return "adrenals"
        if has("pituitary"):
            return "pituitary"
        return "brain"
    if system == "lymphatic":
        if has("spleen"):
            return "spleen"
        if has("thymus"):
            return "thymus"
        return "lymph"
    if system == "urinary":
        if has("bladder", "urethra", "ureteral orifice", "trigone"):
            return "bladder"
        return "kidneys"
    if system == "respiratory":
        if has("trachea", "carina"):
            return "trachea"
        if has("bronch", "lung"):
            return "lungs"
        if has("epiglott", "thyroid cartilage", "cricoid", "arytenoid",
               "corniculate", "cuneiform cartilage", "vocal"):
            return "larynx"
        if has("nasal", "concha"):
            return "nose"
        return "throat"
    if system == "digestive":
        if has("tongue"):
            return "tongue"
        if has("tonsil"):
            return "throat"
        if has("sublingual", "submandibular", "parotid"):
            return "salivary"
        if has("impression of liver"):
            return "liver"
        if has("esophag"):
            return "esophagus"
        if has("stomach", "gastric"):
            return "stomach"
        if has("gallbladder", "cystic duct", "common bile duct"):
            return "gallbladder"
        if has("pancrea", "uncinate"):
            return "pancreas"
        if has("duoden", "jejun", "ileum", "ileocecal junction",
               "mesentery of small"):
            return "small_intestine"
        if has("colon", "caecum", "cecum", "rectum", "append", "taenia",
               "mesocolon", "ileocecal valve", "anal"):
            return "large_intestine"
        return "liver"
    if system == "sensory":
        if has("external ear"):
            return "ears"
        if has("flexor retinaculum"):
            return "connective"
        if has("lacrimal bone"):
            return "skull"
        if has("thalamus", "nuclear", "hth", "optic radiation", "optic tract",
               "chiasma", "dura mater", "preoptic", "supraoptic"):
            return "brain"
        return "eyes"
    if system == "nervous":
        if has("spinal cord", "central canal", "cauda equina"):
            return "spinal_cord"
        return "brain" if head else "nerves"
    if system == "skeletal":
        if has("bone tissue"):
            return "pelvis"  # HuBMAP female: the hip bones are named by tissue
        if has("fibularis", "tibialis", "iliotibial", "levator scapulae",
               "subscapularis", "tensor"):
            return "muscles"
        if has("tooth", "gingiva"):
            return "teeth"
        if has("arytenoid", "corniculate", "cuneiform cartilage", "thyroid cartilage",
               "cricoid"):
            return "larynx"
        if has("alar cartilage", "nasal cartilage"):
            return "nose"
        if has(*SKULL):
            return "skull"
        if has("vertebra", "intervertebral", "sacrum", "coccyx") or n in ("atlas", "axis", "vertebral bone 1", "vertebral bone 2"):
            return "spine"
        if has("rib", "costal", "sternum", "manubrium", "xiphoid"):
            return "ribcage"
        if has("clavicle", "scapula"):
            return "shoulder"
        if has("humerus"):
            return "humerus"
        if has("radius", "ulna", "forearm"):
            return "forearm"
        if has(*CARPAL) or (has("phalanx") and has("finger", "thumb")):
            return "hand"
        if has("hip bone"):
            return "pelvis"
        if has("patella", "cruciate", "collateral ligament", "articular disk of knee",
               "ligament of knee", "perichondular"):
            return "knee"
        if has("femur", "epicondylar"):
            return "femur"
        if has("tibia", "fibula", "leg"):
            return "lower_leg"
        if has(*TARSAL) or has("toe", "sesamoid bone of"):
            return "foot"
        return "bones"
    if system == "muscular":
        if has("papillary"):
            return "heart"
        if head and has("rectus", "oblique", "levator palpebrae"):
            return "eyes"
        if has("diaphragm"):
            return "diaphragm"
        if has("biceps brachii"):
            return "biceps"
        if has("triceps"):
            return "triceps"
        if has("deltoid"):
            return "deltoid"
        if has("pectoralis"):
            return "chest_muscles"
        if has("rectus abdominis", "external oblique", "internal oblique",
               "transversus abdominis"):
            return "abs"
        if has("trapezius", "latissimus", "rhomboid", "erector", "spinalis",
               "longissimus", "iliocostalis"):
            return "back_muscles"
        if has("gluteus"):
            return "glutes"
        if has("rectus femoris", "vastus", "quadriceps"):
            return "quadriceps"
        if has("biceps femoris", "semitendinosus", "semimembranosus"):
            return "hamstrings"
        if has("gastrocnemius", "soleus"):
            return "calf"
        return "muscles"
    if system == "connective":
        if has("calcaneal tendon"):
            return "calf"
        return "connective"
    if system == "arterial":
        return "aorta" if has("aorta") else "arteries"
    if system == "venous":
        return "veins"
    return "bones"


def side_of(name):
    n = name.lower()
    if "left" in n:
        return "L"
    if "right" in n:
        return "R"
    return ""


def center(p):
    return [(p["bounds"][0][i] + p["bounds"][1][i]) / 2 for i in range(3)]


def read_part(chunk_dir, files, p):
    with open(os.path.join(chunk_dir, files[p["chunk"]]), "rb") as fh:
        data = fh.read()
    pos = np.frombuffer(data, np.float32, p["vertexCount"] * 3, p["positions"]).reshape(-1, 3).copy()
    nrm = np.frombuffer(data, np.int16, p["vertexCount"] * 3, p["normals"]).reshape(-1, 3).copy()
    idx = np.frombuffer(data, np.uint32, p["indexCount"], p["indices"]).copy()
    return pos, nrm, idx


def bbox(parts):
    lo = np.array([p["bounds"][0] for p in parts]).min(0)
    hi = np.array([p["bounds"][1] for p in parts]).max(0)
    return lo, hi


def similarity(src, dst):
    """Least-squares scale + translation that maps src points onto dst."""
    src, dst = np.array(src), np.array(dst)
    cs, cd = src.mean(0), dst.mean(0)
    a, b = src - cs, dst - cd
    s = float((a * b).sum() / (a * a).sum())
    return s, cd - s * cs


def build(sex, atlas_path, chunk_dir, out_dir, transplant=None):
    atlas = json.load(open(atlas_path))
    files = [os.path.basename(c["url"]) for c in atlas["chunks"]]
    os.makedirs(out_dir, exist_ok=True)
    for f in files:
        shutil.copyfile(os.path.join(chunk_dir, f), os.path.join(out_dir, f))

    rows = []
    unknown = {}
    for p in atlas["parts"]:
        cx, cy, cz = center(p)
        key = classify(p["name"], p["system"], cy, sex)
        if key is None:
            continue
        unknown.setdefault(key, 0)
        unknown[key] += 1
        lo, hi = p["bounds"]
        name = p["name"]
        if key == "pelvis" and "bone tissue" in name:
            side = "Left" if cx > 0 else "Right"
            name = f"{side} hip bone ({name.replace(' bone tissue', '')} bone)"
        rows.append([p["id"], name, key, side_of(name), p["chunk"],
                     p["positions"], p["normals"], p["indices"],
                     p["vertexCount"], p["indexCount"],
                     *[round(v, 5) for v in lo], *[round(v, 5) for v in hi], 0])

    if transplant:
        extra_name = "extra-0.bin"
        files.append(extra_name)
        chunk_index = len(files) - 1
        buf = bytearray()
        for (pos, nrm, idx, name, key, pid) in transplant:
            def align():
                while len(buf) % 4:
                    buf.append(0)
            align()
            po = len(buf); buf.extend(pos.astype(np.float32).tobytes())
            no = len(buf); buf.extend(nrm.astype(np.int16).tobytes())
            align()
            io = len(buf); buf.extend(idx.astype(np.uint32).tobytes())
            lo, hi = pos.min(0), pos.max(0)
            rows.append([pid, name, key, side_of(name), chunk_index, po, no, io,
                         len(pos), len(idx),
                         *[round(float(v), 5) for v in lo], *[round(float(v), 5) for v in hi], 1])
            unknown[key] = unknown.get(key, 0) + 1
        with open(os.path.join(out_dir, extra_name), "wb") as fh:
            fh.write(buf)

    used = sorted({r[2] for r in rows})
    keys = {k: {"layer": LAYER[k], "whole": k not in SINGLE, "color": COLOR[k]} for k in used}
    lo = np.array([r[10:13] for r in rows]).min(0)
    hi = np.array([r[13:16] for r in rows]).max(0)
    manifest = {
        "sex": sex,
        "source": atlas.get("version"),
        "chunks": files,
        "bounds": [lo.round(4).tolist(), hi.round(4).tolist()],
        "fields": ["id", "name", "key", "side", "chunk", "positions", "normals",
                   "indices", "vertexCount", "indexCount", "minX", "minY", "minZ",
                   "maxX", "maxY", "maxZ", "fitted"],
        "keys": keys,
        "parts": rows,
    }
    with open(os.path.join(out_dir, "manifest.json"), "w") as fh:
        json.dump(manifest, fh, separators=(",", ":"), ensure_ascii=False)
    tris = sum(r[9] for r in rows) // 3
    print(sex, len(rows), "parts", tris, "triangles", json.dumps(unknown, sort_keys=True))
    return manifest


def main():
    ha, fdir, out = sys.argv[1], sys.argv[2], sys.argv[3]
    male_atlas = json.load(open(os.path.join(ha, "public/models/atlas.json")))
    fem_atlas = json.load(open(os.path.join(fdir, "atlas-female.json")))
    fem_files = [os.path.basename(c["url"]) for c in fem_atlas["chunks"]]

    # --- landmarks to place female organs inside the male body
    def pick(atlas, sex, test):
        ps = [p for p in atlas["parts"] if test(p)]
        lo, hi = bbox(ps)
        return (lo + hi) / 2

    fsys = lambda s: (lambda p: p["system"] == s)
    pairs = [
        (pick(fem_atlas, "female", lambda p: p["name"] == "trachea"),
         pick(male_atlas, "male", lambda p: p["name"] == "Trachea")),
        (pick(fem_atlas, "female", lambda p: p["name"] in ("heart left ventricle", "heart right ventricle")),
         pick(male_atlas, "male", lambda p: p["system"] == "cardiac" and "ventricle" in p["name"].lower() and "lateral" not in p["name"].lower() and "third" not in p["name"].lower() and "fourth" not in p["name"].lower())),
        (pick(fem_atlas, "female", lambda p: p["system"] == "urinary" and "ureter" not in p["name"].lower() and "bladder" not in p["name"].lower() and "trigone" not in p["name"].lower()),
         pick(male_atlas, "male", lambda p: p["name"] in ("Left kidney", "Right kidney"))),
        (pick(fem_atlas, "female", lambda p: "gallbladder" in p["name"].lower()),
         pick(male_atlas, "male", lambda p: p["name"] == "Gallbladder")),
        (pick(fem_atlas, "female", lambda p: "pancrea" in p["name"].lower()),
         pick(male_atlas, "male", lambda p: p["name"] == "Pancreas")),
    ]
    s, t = similarity([a for a, _ in pairs], [b for _, b in pairs])
    print("female->male scale", round(s, 3), "shift", t.round(3))

    transplant = []
    # Lungs: fit the female lung segments onto the male bronchial tree box.
    seg = [p for p in fem_atlas["parts"] if "bronchopulmonary segment" in p["name"].lower()]
    flo, fhi = bbox(seg)
    trees = [p for p in male_atlas["parts"] if "bronchial tree" in p["name"]]
    mlo, mhi = bbox(trees)
    mc = (mlo + mhi) / 2
    half = (mhi - mlo) / 2 * np.array([1.12, 1.0, 1.15])
    mlo, mhi = mc - half, mc + half
    mhi[1] += 0.02
    scale = (mhi - mlo) / (fhi - flo)
    for p in seg:
        pos, nrm, idx = read_part(fdir, fem_files, p)
        pos = (pos - flo) * scale + mlo
        side = "Left" if pos[:, 0].mean() > 0 else "Right"
        nm = p["name"]
        if "left" not in nm.lower() and "right" not in nm.lower():
            nm = f"{side} lung – {nm}"
        transplant.append((pos, nrm, idx, nm, "lungs", "F-" + p["id"]))

    # Liver: whole-organ similarity transform from landmarks.
    liver = [p for p in fem_atlas["parts"] if p["system"] == "digestive"
             and classify(p["name"], p["system"], center(p)[1], "female") == "liver"
             and "ligament" not in p["name"].lower()]
    for p in liver:
        pos, nrm, idx = read_part(fdir, fem_files, p)
        pos = pos * s + t
        transplant.append((pos, nrm, idx, p["name"][0].upper() + p["name"][1:], "liver", "F-" + p["id"]))

    build("male", os.path.join(ha, "public/models/atlas.json"), os.path.join(ha, "public/models"),
          os.path.join(out, "male"), transplant)
    build("female", os.path.join(fdir, "atlas-female.json"), fdir, os.path.join(out, "female"))


if __name__ == "__main__":
    main()
