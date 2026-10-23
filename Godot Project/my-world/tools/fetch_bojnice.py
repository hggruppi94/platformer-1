"""
Builds tools/bojnice_footprint.json: the real, 1:1 footprint and heights of Bojnice Castle (Bojnice, Slovakia),
taken from OpenStreetMap's 3D building data. tools/build_town.gd turns it into the castle school.

    python tools/fetch_bojnice.py                  (downloads from the Overpass API)
    python tools/fetch_bojnice.py --cached DIR     (uses bojnice.json + relgeom.json saved in DIR instead)

Map data (c) OpenStreetMap contributors, available under the Open Database License (ODbL):
https://www.openstreetmap.org/copyright

What comes out, all in meters around the castle's middle (+X east, +Z south, as in the town):
  ring:  the castle's outline minus its courtyards, triangulated (holes bridged), drawn as a low base block
  parts: every building:part (towers, wings, the keep): outline, wall base and top, roof height, triangles
Parts with no height in OSM get a guess (DEFAULTS below). Roofs are drawn as steep hipped roofs; OSM's
roof:height sets how tall, otherwise they get Bojnice's steep pitch.
"""
import json
import math
import os
import sys
import urllib.parse
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(HERE, "bojnice_footprint.json")
LAT0, LON0 = 48.7800, 18.5775
CASTLE_RELATION = 903437                     # the castle building (outer outline + courtyards)
GATE_PART = 243261712                        # the north gate building, where the main entrance is
OVERPASS = "https://overpass.kumi.systems/api/interpreter"

# Parts OSM has no height for: total height in meters (roof included), from photos of the castle
DEFAULTS = {
    243261707: 18,   # east bastion
    243398820: 22,   # west round stair tower
    292702106: 16,   # south chapel tower
    292702107: 16,   # south artillery tower
    292702110: 16,   # southeast wing
    292702111: 18,   # east wing
}
RING_HEIGHT = 8.0                            # the base block under everything (shows as curtain walls)
DEFAULT_PITCH = 1.5                          # roof rise per meter in from the eaves, when OSM gives none
MAX_DEFAULT_ROOF = 12.0


def overpass(query):
    req = urllib.request.Request(OVERPASS, data=urllib.parse.urlencode({"data": query}).encode(),
                                 headers={"User-Agent": "platformer-1 castle builder"})
    with urllib.request.urlopen(req, timeout=180) as r:
        return json.load(r)


def to_m(geom):
    k = 111320 * math.cos(math.radians(LAT0))
    pts = [((p["lon"] - LON0) * k, -(p["lat"] - LAT0) * 110540) for p in geom]
    if len(pts) > 1 and pts[0] == pts[-1]:
        pts = pts[:-1]
    return pts


def area(pts):
    return sum(pts[i - 1][0] * pts[i][1] - pts[i][0] * pts[i - 1][1] for i in range(len(pts))) / 2


def orient(pts, positive):
    return pts if (area(pts) > 0) == positive else pts[::-1]


def inside(pt, poly):
    x, y = pt
    c = False
    for i in range(len(poly)):
        x1, y1 = poly[i]
        x2, y2 = poly[i - 1]
        if (y1 > y) != (y2 > y) and x < (x2 - x1) * (y - y1) / (y2 - y1) + x1:
            c = not c
    return c


def cross(o, a, b):
    return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])


def seg_hit(p1, p2, q1, q2):
    # proper crossing of two segments (touching at ends doesn't count)
    d1, d2 = cross(q1, q2, p1), cross(q1, q2, p2)
    d3, d4 = cross(p1, p2, q1), cross(p1, p2, q2)
    return d1 * d2 < -1e-9 and d3 * d4 < -1e-9


def bridge(outer, holes):
    # Join each hole to the outline with a two-way cut, so the whole ring becomes one simple polygon
    poly = orient(outer, True)
    holes = sorted((orient(h, False) for h in holes), key=lambda h: -max(p[0] for p in h))
    for hi, hole in enumerate(holes):
        m = max(range(len(hole)), key=lambda i: hole[i][0])
        mp = hole[m]
        others = holes[hi + 1:]
        best = None
        for vi in sorted(range(len(poly)), key=lambda i: math.dist(poly[i], mp)):
            v = poly[vi]
            ok = True
            for ring in [poly, hole] + others:
                for i in range(len(ring)):
                    if seg_hit(mp, v, ring[i - 1], ring[i]):
                        ok = False
                        break
                if not ok:
                    break
            if ok:
                best = vi
                break
        h = hole[m:] + hole[:m] + [hole[m]]
        poly = poly[:best + 1] + h + [poly[best]] + poly[best + 1:]
    return poly


def in_tri(p, a, b, c):
    return cross(a, b, p) >= -1e-9 and cross(b, c, p) >= -1e-9 and cross(c, a, p) >= -1e-9


def earclip(pts):
    # Counter-clockwise polygon (bridged holes allowed) -> triangles as index triples
    idx = list(range(len(pts)))
    tris = []
    guard = 0
    while len(idx) > 3 and guard < 10000:
        guard += 1
        n = len(idx)
        cut = None
        for k in range(n):
            a, b, c = idx[k - 1], idx[k], idx[(k + 1) % n]
            if cross(pts[a], pts[b], pts[c]) <= 1e-9:
                continue
            blocked = False
            for o in idx:
                if o in (a, b, c) or pts[o] in (pts[a], pts[b], pts[c]):
                    continue
                if in_tri(pts[o], pts[a], pts[b], pts[c]):
                    blocked = True
                    break
            if not blocked:
                cut = k
                break
        if cut is None:                       # only slivers left: drop the flattest corner
            cut = min(range(n), key=lambda k: abs(cross(pts[idx[k - 1]], pts[idx[k]], pts[idx[(k + 1) % n]])))
            idx.pop(cut)
            continue
        tris.append([idx[cut - 1], idx[cut], idx[(cut + 1) % n]])
        idx.pop(cut)
    if len(idx) == 3 and cross(pts[idx[0]], pts[idx[1]], pts[idx[2]]) > 1e-9:
        tris.append(idx[:])
    return tris


def inner_radius(pts):
    # how far in from the walls the middle of the part is (for the roof pitch)
    xs = [p[0] for p in pts]
    zs = [p[1] for p in pts]
    best = 0.0
    steps = 24
    for i in range(steps + 1):
        for j in range(steps + 1):
            q = (min(xs) + (max(xs) - min(xs)) * i / steps, min(zs) + (max(zs) - min(zs)) * j / steps)
            if inside(q, pts):
                d = min(dist_seg(q, pts[k - 1], pts[k]) for k in range(len(pts)))
                best = max(best, d)
    return best


def dist_seg(p, a, b):
    ax, az = b[0] - a[0], b[1] - a[1]
    t = max(0.0, min(1.0, ((p[0] - a[0]) * ax + (p[1] - a[1]) * az) / max(ax * ax + az * az, 1e-12)))
    return math.dist(p, (a[0] + ax * t, a[1] + az * t))


def main():
    if "--cached" in sys.argv:
        d = sys.argv[sys.argv.index("--cached") + 1]
        parts_raw = json.load(open(os.path.join(d, "bojnice.json")))["elements"]
        rel = json.load(open(os.path.join(d, "relgeom.json")))["elements"][0]
    else:
        parts_raw = overpass('[out:json];way(around:150,%f,%f)["building:part"];out tags geom;' % (LAT0, LON0))["elements"]
        rel = overpass("[out:json];relation(%d);out geom;" % CASTLE_RELATION)["elements"][0]
    outer = to_m([m for m in rel["members"] if m["role"] == "outer"][0]["geometry"])
    courts = [to_m(m["geometry"]) for m in rel["members"] if m["role"] == "inner"]
    # Only the courtyards that open into the outer ward; the ones inside the keep are covered by its parts
    courts = [c for c in courts if not any(all(inside(p, o) for p in c) for o in courts if o is not c)]

    cx = (min(p[0] for p in outer) + max(p[0] for p in outer)) / 2
    cz = (min(p[1] for p in outer) + max(p[1] for p in outer)) / 2

    def local(pts):
        return [(round(p[0] - cx, 2), round(p[1] - cz, 2)) for p in pts]

    ring = bridge(local(outer), [local(c) for c in courts])
    out = {
        "source": "OpenStreetMap contributors, ODbL (https://www.openstreetmap.org/copyright)",
        "center_latlon": [LAT0, LON0],
        "ring": {"outline": local(orient(outer, True)), "courts": [local(c) for c in courts],
                 "points": ring, "tris": earclip(ring), "height": RING_HEIGHT},
        "parts": [],
    }
    for e in parts_raw:
        t = e.get("tags", {})
        if "building:part" not in t or e["type"] != "way":
            continue
        pts = to_m(e["geometry"])
        c = (sum(p[0] for p in pts) / len(pts), sum(p[1] for p in pts) / len(pts))
        if not inside(c, outer):
            continue
        pts = local(orient(pts, True))
        h = float(t.get("height", DEFAULTS.get(e["id"], 16)))
        base = float(t.get("min_height", 0))
        r_in = inner_radius(pts)
        if "roof:height" in t:
            roof = float(t["roof:height"])
        else:
            roof = min(DEFAULT_PITCH * r_in, MAX_DEFAULT_ROOF)
            h += roof                                  # a guessed roof sits on top of the given wall height
        out["parts"].append({
            "id": e["id"], "points": pts, "tris": earclip(pts), "base": base, "wall_top": round(h - roof, 2),
            "roof": round(roof, 2), "inner_radius": round(r_in, 2), "shape": t.get("roof:shape", "hipped"),
            "gate": e["id"] == GATE_PART, "roof_colour": t.get("roof:colour", ""),
        })
    out["parts"].sort(key=lambda p: p["id"])
    with open(OUT, "w", encoding="utf-8", newline="\n") as f:
        json.dump(out, f, indent=1)
    print("wrote", OUT, len(out["parts"]), "parts,", len(out["ring"]["tris"]), "ring triangles")
    for p in out["parts"]:
        a = abs(area(p["points"]))
        tri_a = sum(abs(cross(p["points"][i], p["points"][j], p["points"][k])) / 2 for i, j, k in p["tris"])
        if abs(a - tri_a) > 0.5:
            print("  WARNING part", p["id"], "area", round(a), "triangles cover", round(tri_a))
    ra = abs(area(out["ring"]["outline"])) - sum(abs(area(c)) for c in out["ring"]["courts"])
    rt = sum(abs(cross(ring[i], ring[j], ring[k])) / 2 for i, j, k in out["ring"]["tris"])
    print("  ring area", round(ra), "triangles cover", round(rt))


if __name__ == "__main__":
    main()
