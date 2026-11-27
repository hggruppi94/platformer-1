# Shared by rig.py and the parts preview: each face's colour from the model's own texture, and the faces sorted into
# named parts (tools/trellis_characters/<name>.json "parts") by colour AND height, so a red bow on top of the head and
# red hair are told apart, and white eyes aren't taken for the white shirt.
import bpy, bmesh
import numpy as np


def base_image(ob):
    for s in ob.material_slots:
        m = s.material
        if not (m and m.use_nodes):
            continue
        for n in m.node_tree.nodes:
            if n.type == "BSDF_PRINCIPLED":
                link = n.inputs["Base Color"].links
                if link and link[0].from_node.type == "TEX_IMAGE":
                    return link[0].from_node.image
    return None


def face_colours(ob):
    """sRGB 0..255 colour of each face: the texture read at three points inside the face (its middle and halfway
    to two corners), averaged."""
    me = ob.data
    img = base_image(ob)
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    px = px.reshape(h, w, 4)[:, :, :3]
    if img.colorspace_settings.name != "sRGB":
        px = np.clip(px, 0, 1) ** (1 / 2.2)
    else:
        px = np.clip(px, 0, 1)
    uv = me.uv_layers.active.data
    uvs = np.empty(len(uv) * 2, dtype=np.float32)
    uv.foreach_get("uv", uvs)
    uvs = uvs.reshape(-1, 2)
    out = np.zeros((len(me.polygons), 3))
    for p in me.polygons:
        ls = list(p.loop_indices)
        c = uvs[ls].mean(0)
        pts = [c, (c + uvs[ls[0]]) / 2, (c + uvs[ls[1]]) / 2]
        cols = [px[min(h - 1, max(0, int(q[1] * h))), min(w - 1, max(0, int(q[0] * w)))] for q in pts]
        out[p.index] = np.mean(cols, 0) * 255
    return out


def classify(ob, parts, height, smooth=3, island=40):
    """Index into parts for every face. A part: {"name", "rgb": [[r,g,b], ...], "z": [lo, hi] as a share of the
    height (optional), "x": [lo, hi] in metres (optional)}. Nearest colour among the parts allowed at the face's
    place; then each face takes the most common part round it (a few rounds) and islands smaller than `island` faces
    join the part they sit in, so the borders come out clean."""
    me = ob.data
    col = face_colours(ob)
    cen = np.array([p.center[:] for p in me.polygons])
    zf = cen[:, 2] / height
    lab = np.zeros(len(me.polygons), dtype=int)
    for i in range(len(me.polygons)):
        best, bd = 0, 1e18
        for k, part in enumerate(parts):
            lo, hi = part.get("z", [-1, 2])
            if not (lo <= zf[i] <= hi):
                continue
            xr = part.get("absx")
            if xr and not (xr[0] <= abs(cen[i, 0]) <= xr[1]):
                continue
            for rgb in part["rgb"]:
                d = float(((col[i] - rgb) ** 2).sum())
                if d < bd:
                    best, bd = k, d
        lab[i] = best
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    nb = [[f2.index for e in f.edges for f2 in e.link_faces if f2 is not f] for f in bm.faces]
    for _ in range(smooth):
        new = lab.copy()
        for i, n in enumerate(nb):
            if len(n) >= 2:
                v = np.bincount(lab[n], minlength=len(parts))
                if v.max() >= 2 and v.argmax() != lab[i] and v[lab[i]] == 0:
                    new[i] = v.argmax()
        lab = new
    seen = np.zeros(len(lab), bool)
    for s in range(len(lab)):
        if seen[s]:
            continue
        comp, stack, border = [], [s], []
        seen[s] = True
        while stack:
            f = stack.pop()
            comp.append(f)
            for g in nb[f]:
                if lab[g] == lab[s]:
                    if not seen[g]:
                        seen[g] = True
                        stack.append(g)
                else:
                    border.append(lab[g])
        if len(comp) < island and border:
            lab[comp] = np.bincount(border).argmax()
    bm.free()
    return lab, col


def apply_parts(ob, parts, lab):
    """One material per part, each a copy of the model's own material (same texture, so the look doesn't change),
    named after the part, so the game can find, recolour or hide a part by name."""
    me = ob.data
    src = ob.material_slots[0].material
    keep = [p.material_index for p in me.polygons]
    me.materials.clear()
    for part in parts:
        m = src.copy()
        m.name = part["name"]
        me.materials.append(m)
    for p in me.polygons:
        p.material_index = int(lab[p.index])
    return keep
