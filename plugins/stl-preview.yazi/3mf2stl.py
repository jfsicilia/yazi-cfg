"""Convert a 3MF (including Bambu/Orca multi-file ones) to a binary STL. Stdlib only."""
import struct
import sys
import zipfile
import xml.etree.ElementTree as ET

src, out = sys.argv[1], sys.argv[2]
z = zipfile.ZipFile(src)


def local(tag):
    return tag.rsplit("}", 1)[-1]


def attr(el, name):
    for k, v in el.attrib.items():
        if k.rsplit("}", 1)[-1] == name:
            return v


def matrix(s):
    if not s:
        return None
    return [float(x) for x in s.split()]


def apply(m, p):
    if m is None:
        return p
    x, y, z_ = p
    return (
        x * m[0] + y * m[3] + z_ * m[6] + m[9],
        x * m[1] + y * m[4] + z_ * m[7] + m[10],
        x * m[2] + y * m[5] + z_ * m[8] + m[11],
    )


def compose(inner, outer):
    # point -> inner -> outer, as 4x3 row-vector matrices
    if inner is None:
        return outer
    if outer is None:
        return inner
    cols = []
    rows = [inner[i * 3:i * 3 + 3] for i in range(4)]
    res = []
    for r in rows:
        p = (r[0], r[1], r[2])
        if r is rows[3]:
            q = apply(outer, p)
        else:
            q = apply(outer[:9] + [0, 0, 0], p)
        res.extend(q)
    return res


models = {}


def load(path):
    path = path.lstrip("/")
    if path not in models:
        root = ET.fromstring(z.read(path))
        objs = {}
        build = []
        for el in root.iter():
            t = local(el.tag)
            if t == "object":
                objs[attr(el, "id")] = el
            elif t == "item":
                build.append(el)
        models[path] = (objs, build)
    return models[path]


tris = []


def emit(path, oid, m):
    objs, _ = load(path)
    obj = objs[oid]
    for el in obj.iter():
        t = local(el.tag)
        if t == "mesh":
            verts, faces = [], []
            for c in el.iter():
                ct = local(c.tag)
                if ct == "vertex":
                    verts.append((float(c.get("x")), float(c.get("y")), float(c.get("z"))))
                elif ct == "triangle":
                    faces.append((int(c.get("v1")), int(c.get("v2")), int(c.get("v3"))))
            for a, b, c in faces:
                tris.append(tuple(apply(m, verts[i]) for i in (a, b, c)))
        elif t == "component":
            cpath = attr(el, "path") or path
            emit(cpath, attr(el, "objectid"), compose(matrix(el.get("transform")), m))


main = next(n for n in z.namelist() if n.lower().endswith("3d/3dmodel.model"))
_, build = load(main)
for item in build:
    emit(main, item.get("objectid"), matrix(item.get("transform")))

with open(out, "wb") as f:
    f.write(b"\0" * 80)
    f.write(struct.pack("<I", len(tris)))
    for a, b, c in tris:
        f.write(struct.pack("<12fH", 0, 0, 0, *a, *b, *c, 0))
