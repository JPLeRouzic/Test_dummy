"""Draws the 2D body pictures that the app shows without the 3D pack.

For each body (male, female), each side (front, back, side) and each mix of
layers, two pictures are made from the 3D models:

  * <mix>.webp     the colour picture with a transparent background;
  * <mix>.ids.png  the "tap map": every pixel holds the number of the part
                   drawn there (red + 256 * green, 0 = nothing), at half size.

A mix is written with one letter per layer, in this order: o (organs),
b (bones), m (muscles), v (vessels), n (nerves). "s" is the skin alone; the
app lays it over the other layers, see-through.

It needs Python with Playwright and Pillow (the same as the viewer tests):

  python3 tool/build_atlas.py <models dir> assets/web assets/atlas
"""

import base64
import io
import itertools
import json
import os
import shutil
import subprocess
import sys
import tempfile
import time

from PIL import Image
from playwright.sync_api import sync_playwright

LAYERS = [("o", "organs"), ("b", "bones"), ("m", "muscles"), ("v", "vessels"), ("n", "nerves")]
VIEWS = ["front", "back", "side"]
HEIGHT = 2000          # colour pictures
ID_SCALE = 2           # tap maps are this many times smaller
WEBP_QUALITY = 80


def mixes():
    out = []
    for n in range(1, len(LAYERS) + 1):
        for combo in itertools.combinations(LAYERS, n):
            out.append(("".join(c for c, _ in combo), [name for _, name in combo]))
    out.append(("s", ["skin"]))
    return out


def decode(data_url):
    return Image.open(io.BytesIO(base64.b64decode(data_url.split(",", 1)[1])))


def main():
    models, web, out = sys.argv[1], sys.argv[2], sys.argv[3]
    only = sys.argv[4].split(",") if len(sys.argv) > 4 else None
    site = tempfile.mkdtemp()
    for name in os.listdir(web):
        os.symlink(os.path.abspath(os.path.join(web, name)), os.path.join(site, name))
    os.symlink(os.path.abspath(models), os.path.join(site, "models"))
    port = 8791
    server = subprocess.Popen([sys.executable, "-m", "http.server", str(port), "-d", site],
                              stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1)
    try:
        with sync_playwright() as pw:
            browser = pw.chromium.launch(args=["--use-gl=angle", "--use-angle=swiftshader",
                                               "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
            for sex in ("male", "female"):
                if only and sex not in only:
                    continue
                page = browser.new_page(viewport={"width": 400, "height": 400})
                page.goto(f"http://127.0.0.1:{port}/index.html?atlas=1")
                page.wait_for_function("window.anatomoAtlas !== undefined")
                info = page.evaluate(f"anatomoAtlas.open('{sex}')")
                with open(os.path.join(models, sex, "manifest.json"), encoding="utf-8") as fh:
                    man = json.load(fh)
                seen = set()
                images = {}
                for view in VIEWS:
                    folder = os.path.join(out, sex, view)
                    os.makedirs(folder, exist_ok=True)
                    for code, layers in mixes():
                        t0 = time.time()
                        shot = page.evaluate("([v, l, h]) => anatomoAtlas.shot(v, l, h, 'color')",
                                             [view, layers, HEIGHT])
                        img = decode(shot["data"]).convert("RGBA")
                        img.save(os.path.join(folder, code + ".webp"), "WEBP",
                                 quality=WEBP_QUALITY, alpha_quality=90, method=6)
                        ids = page.evaluate("([v, l, h]) => anatomoAtlas.shot(v, l, h, 'ids')",
                                            [view, layers, HEIGHT // ID_SCALE])
                        idimg = decode(ids["data"]).convert("RGB")
                        idimg.save(os.path.join(folder, code + ".ids.png"), optimize=True)
                        r, g, _ = idimg.split()
                        for v in set(zip(r.getdata(), g.getdata())):
                            n = v[0] + 256 * v[1]
                            if n:
                                seen.add(n - 1)
                        images[view] = [shot["width"], shot["height"], ids["width"], ids["height"]]
                        print(sex, view, code, shot["width"], "x", shot["height"],
                              f"{time.time() - t0:.1f}s", flush=True)
                page.close()

                F = {f: i for i, f in enumerate(man["fields"])}
                atlas = {
                    "sex": sex,
                    "layers": {c: n for c, n in LAYERS + [("s", "skin")]},
                    "views": {v: {"size": images[v][:2], "ids": images[v][2:]} for v in VIEWS},
                    "keys": man["keys"],
                    "fields": ["id", "name", "key", "visible"],
                    "parts": [[r[F["id"]], r[F["name"]], r[F["key"]], 1 if i in seen else 0]
                              for i, r in enumerate(man["parts"])],
                    "fitted": sorted({r[F["key"]] for r in man["parts"] if r[F["fitted"]]}),
                }
                with open(os.path.join(out, sex, "atlas.json"), "w", encoding="utf-8") as fh:
                    json.dump(atlas, fh, separators=(",", ":"), ensure_ascii=False)
            browser.close()
    finally:
        server.terminate()
        shutil.rmtree(site, ignore_errors=True)


if __name__ == "__main__":
    main()
