"""Re-pack the model chunks so that every chunk holds one layer only.

The viewer then loads a layer (muscles, nerves, ...) only when it is switched
on. Run it after build_models.py:

  python3 tool/repack_by_layer.py pack/models
"""

import json
import os
import sys

TARGET = 5 * 1024 * 1024  # start a new chunk after about 5 MB


def pad4(buf):
    while len(buf) % 4:
        buf.append(0)


def repack(model_dir):
    path = os.path.join(model_dir, "manifest.json")
    with open(path, encoding="utf-8") as fh:
        man = json.load(fh)
    F = {name: i for i, name in enumerate(man["fields"])}
    old = []
    for name in man["chunks"]:
        with open(os.path.join(model_dir, name), "rb") as fh:
            old.append(fh.read())

    by_layer = {}
    for row in man["parts"]:
        layer = man["keys"][row[F["key"]]]["layer"]
        by_layer.setdefault(layer, []).append(row)

    new_names, new_layers = [], []
    for layer in sorted(by_layer):
        blob = bytearray()
        count = 0

        def flush():
            nonlocal blob, count
            if not blob:
                return
            name = f"{layer}-{count}.bin"
            with open(os.path.join(model_dir, name + ".tmp"), "wb") as fh:
                fh.write(blob)
            new_names.append(name)
            new_layers.append(layer)
            count += 1
            blob = bytearray()

        for row in by_layer[layer]:
            if len(blob) > TARGET:
                flush()
            src = old[row[F["chunk"]]]
            vc, ic = row[F["vertexCount"]], row[F["indexCount"]]
            pos, nrm, idx = row[F["positions"]], row[F["normals"]], row[F["indices"]]
            pad4(blob)
            row[F["positions"]] = len(blob)
            blob += src[pos:pos + vc * 12]
            pad4(blob)
            row[F["normals"]] = len(blob)
            blob += src[nrm:nrm + vc * 6]
            pad4(blob)
            row[F["indices"]] = len(blob)
            blob += src[idx:idx + ic * 4]
            row[F["chunk"]] = len(new_names)  # the chunk that flush() is about to add
        flush()

    # the chunk index written above is only right if flush() ran as expected
    for row in man["parts"]:
        layer = man["keys"][row[F["key"]]]["layer"]
        assert new_layers[row[F["chunk"]]] == layer, "chunk/layer mismatch"

    for name in man["chunks"]:
        os.remove(os.path.join(model_dir, name))
    for name in new_names:
        os.replace(os.path.join(model_dir, name + ".tmp"), os.path.join(model_dir, name))
    man["chunks"] = new_names
    man["chunkLayers"] = new_layers
    with open(path, "w", encoding="utf-8") as fh:
        json.dump(man, fh, separators=(",", ":"))
    print(os.path.basename(model_dir), len(new_names), "chunks:", dict(zip(new_names, new_layers)))


if __name__ == "__main__":
    for sex in ("male", "female"):
        repack(os.path.join(sys.argv[1], sex))
