"""Builds data/tracks/melbourne_2012.json (Albert Park, 1996-2020 GP layout) from open data.

Sources (cached in tools/data/raw/, re-fetch with fetch_sources.py):
  - TUMFTM racetrack-database Melbourne.csv (LGPL-3.0): centreline + measured track widths.
  - OpenStreetMap (ODbL): circuit relation 280443 + disused raceway ways (pre-2021 layout) to
    georeference the centreline; lake, trees, buildings and parks for the environment.
  - Copernicus DEM GLO-90 via the Open-Meteo elevation API: terrain heights.
Kerbs, run-off and walls are not in any open dataset: they are derived from the real corner
geometry (curvature) with Albert Park's typical layout (gravel outside slow corners, grass on
straights, concrete walls close to the track) and are marked as approximate in the output.

Coordinates: metres, x east, y south (Godot's y-down 2D), origin at ORIGIN_LATLON.
Run: python -I tools/data/build_melbourne.py
"""
import glob
import json
import math
import os
# OSM API downloads only; Python 3.13's expat ignores external entities and limits entity expansion.
import xml.etree.ElementTree as ET

import numpy as np
from scipy.ndimage import gaussian_filter1d
from scipy.optimize import minimize
from scipy.spatial import cKDTree

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw", "osm")
OUT = os.path.join(HERE, "..", "..", "data", "tracks", "melbourne_2012.json")
ORIGIN_LATLON = (-37.8497, 144.9680)
CIRCUIT_RELATION = "280443"
LAKE_RELATION = "346429"
CAR_MARGIN = 1.2          # racing line keeps this far from the asphalt edge (half car + safety)
KERB_RADIUS = 250.0       # corners tighter than this get kerbs
GRAVEL_RADIUS = 160.0     # ...and tighter than this get a gravel trap on the outside
ENV_RADIUS = 380.0        # buildings closer than this to the track are kept


def project(lat, lon):
    lat0, lon0 = ORIGIN_LATLON
    return ((lon - lon0) * 111320.0 * math.cos(math.radians(lat0)), -(lat - lat0) * 110574.0)


def load_osm():
    nodes, node_tags, ways, rels = {}, {}, {}, {}
    for f in sorted(glob.glob(os.path.join(RAW, "map_*.osm"))):
        for e in ET.parse(f).getroot():
            tags = {t.get("k"): t.get("v") for t in e.findall("tag")}
            if e.tag == "node":
                nodes[e.get("id")] = project(float(e.get("lat")), float(e.get("lon")))
                if tags:
                    node_tags[e.get("id")] = tags
            elif e.tag == "way":
                ways[e.get("id")] = (tags, [n.get("ref") for n in e.findall("nd")])
            elif e.tag == "relation":
                rels[e.get("id")] = (tags, [(m.get("type"), m.get("ref"), m.get("role")) for m in e.findall("member")])
    return nodes, node_tags, ways, rels


def best_rigid(a, b):
    ca, cb = a.mean(0), b.mean(0)
    u, _, vt = np.linalg.svd((a - ca).T @ (b - cb))
    r = vt.T @ u.T
    if np.linalg.det(r) < 0:
        vt[1] *= -1
        r = vt.T @ u.T
    return r, cb - r @ ca


def align_centreline(tum_xy, osm_xy):
    """Rigid ICP from several starting angles; returns the aligned points and the residuals."""
    tree = cKDTree(osm_xy)
    best = None
    for deg in range(0, 360, 10):
        a = math.radians(deg)
        rot = np.array([[math.cos(a), -math.sin(a)], [math.sin(a), math.cos(a)]])
        q = (tum_xy - tum_xy.mean(0)) @ rot.T + osm_xy.mean(0)
        for _ in range(60):
            _, idx = tree.query(q)
            r, t = best_rigid(q, osm_xy[idx])
            q = q @ r.T + t
        d, _ = tree.query(q)
        med = float(np.median(d))
        if best is None or med < best[0]:
            best = (med, q, d)
    return best[1], best[2]


def left_normals(p):
    t = np.roll(p, -1, axis=0) - np.roll(p, 1, axis=0)
    t /= np.linalg.norm(t, axis=1, keepdims=True)
    return np.stack([t[:, 1], -t[:, 0]], axis=1), t  # Vector2.orthogonal(): the driver's left in y-down


def signed_curvature(p):
    """Positive = turning right (clockwise on screen)."""
    n = len(p)
    k = np.zeros(n)
    for i in range(n):
        a, b, c = p[i - 1], p[i], p[(i + 1) % n]
        ab, bc = b - a, c - b
        cross = ab[0] * bc[1] - ab[1] * bc[0]
        denom = np.linalg.norm(ab) * np.linalg.norm(bc) * np.linalg.norm(c - a)
        k[i] = 2.0 * cross / denom if denom > 1e-9 else 0.0
    return gaussian_filter1d(k, 2.0, mode="wrap")


def bilinear(grid, x, y):
    gx = (x - grid["x0"]) / grid["step"]
    gy = (y - grid["y0"]) / grid["step"]
    i0 = int(np.clip(math.floor(gx), 0, grid["nx"] - 2))
    j0 = int(np.clip(math.floor(gy), 0, grid["ny"] - 2))
    fx, fy = np.clip(gx - i0, 0, 1), np.clip(gy - j0, 0, 1)
    h = grid["heights"]
    nx = grid["nx"]
    v00, v10 = h[j0 * nx + i0], h[j0 * nx + i0 + 1]
    v01, v11 = h[(j0 + 1) * nx + i0], h[(j0 + 1) * nx + i0 + 1]
    return (v00 * (1 - fx) + v10 * fx) * (1 - fy) + (v01 * (1 - fx) + v11 * fx) * fy


def racing_line(p, normals, wl, wr):
    """Minimum-curvature line: lateral offset n_i (+ = left) minimising sum |P[i-1] - 2P[i] + P[i+1]|^2."""
    n = len(p)

    def second_diff(v):
        return np.roll(v, 1, axis=0) - 2 * v + np.roll(v, -1, axis=0)

    def f(off):
        q = p + normals * off[:, None]
        d = second_diff(q)
        g_q = 2 * second_diff(d)  # D^T D is symmetric for the circular second difference
        return float((d ** 2).sum()), (g_q * normals).sum(axis=1)

    bounds = [(-(wr[i] - CAR_MARGIN), wl[i] - CAR_MARGIN) for i in range(n)]
    # Scaled objective (positions are ~1e3 m, curvature terms tiny) and a long run: the
    # optimiser must push the line out to the walls on corner entry and exit.
    res = minimize(lambda x: tuple(v * 1e3 for v in f(x)), np.zeros(n), jac=True, method="L-BFGS-B",
                   bounds=bounds, options={"maxiter": 200000, "maxfun": 400000, "ftol": 1e-15, "gtol": 1e-12})
    print(f"racing line: {res.nit} iterations, success={res.success} ({res.message})")
    return res.x


def ring_from_relation(rel, ways, nodes):
    """Assembles a multipolygon's outer ways into rings; returns the largest."""
    segs = [ways[ref][1] for t, ref, role in rel[1] if t == "way" and role in ("outer", "") and ref in ways]
    rings = []
    while segs:
        ring = list(segs.pop(0))
        changed = True
        while changed and ring[0] != ring[-1]:
            changed = False
            for s in segs:
                if s[0] == ring[-1]:
                    ring += s[1:]
                elif s[-1] == ring[-1]:
                    ring += list(reversed(s))[1:]
                elif s[-1] == ring[0]:
                    ring = s[:-1] + ring
                elif s[0] == ring[0]:
                    ring = list(reversed(s))[:-1] + ring
                else:
                    continue
                segs.remove(s)
                changed = True
                break
        rings.append([nodes[n] for n in ring if n in nodes])
    return max(rings, key=len)


def building_height(tags):
    if "height" in tags:
        try:
            return float(tags["height"].split()[0])
        except ValueError:
            pass
    if "building:levels" in tags:
        try:
            return float(tags["building:levels"]) * 3.2
        except ValueError:
            pass
    return {"apartments": 14.0, "commercial": 10.0, "office": 14.0, "retail": 6.0, "school": 9.0,
            "shed": 3.0, "garage": 3.0}.get(tags.get("building"), 6.5)


def main():
    nodes, node_tags, ways, rels = load_osm()

    # --- Centreline: TUM geometry, georeferenced on OSM -------------------------------------
    osm_pts = []
    for t, ref, _ in rels[CIRCUIT_RELATION][1]:
        if t == "way" and ref in ways:
            osm_pts += [nodes[n] for n in ways[ref][1] if n in nodes]
    for tags, nd in ways.values():
        if tags.get("disused:highway") == "raceway":
            osm_pts += [nodes[n] for n in nd if n in nodes]
    tum = np.loadtxt(os.path.join(RAW, "tum_melbourne.csv"), delimiter=",", comments="#")
    tum_xy = tum[:, :2] * np.array([1.0, -1.0])  # TUM is north-up; flip to y-down like OSM
    # The survey has a few single-point kinks (T15 reads as a 15 m radius); a light
    # smoothing (~7 m) turns them into the arcs the asphalt actually follows.
    tum_xy = np.stack([gaussian_filter1d(tum_xy[:, 0], 1.5, mode="wrap"),
                       gaussian_filter1d(tum_xy[:, 1], 1.5, mode="wrap")], axis=1)
    p, residual = align_centreline(tum_xy, np.array(osm_pts))
    w_right, w_left = tum[:, 2].copy(), tum[:, 3].copy()
    n = len(p)
    # Albert Park runs clockwise: in y-down coordinates the shoelace area is positive.
    area = 0.5 * np.sum(p[:, 0] * np.roll(p[:, 1], -1) - np.roll(p[:, 0], -1) * p[:, 1])
    assert area > 0, "expected the clockwise 1996-2020 direction"
    seg = np.linalg.norm(np.roll(p, -1, axis=0) - p, axis=1)
    s = np.concatenate([[0.0], np.cumsum(seg)])
    length = float(s[-1])
    normals, tangents = left_normals(p)
    kappa = signed_curvature(p)

    # --- Heights from the DEM -----------------------------------------------------------------
    dem = json.load(open(os.path.join(RAW, "albert_park_elevation.json")))
    grid = {k: dem[k] for k in ("x0", "y0", "step", "nx", "ny", "heights")}
    heights = gaussian_filter1d(np.array([bilinear(grid, x, y) for x, y in p]), 8.0, mode="wrap")

    # --- Kerbs, run-off and walls (approximate, from the corner geometry) --------------------
    radius = np.where(np.abs(kappa) > 1e-6, 1.0 / np.maximum(np.abs(kappa), 1e-6), 1e6)
    corner = radius < KERB_RADIUS
    slow = radius < GRAVEL_RADIUS
    # extend each zone ~40 m either side (entry and exit)
    spread = int(40.0 / (length / n))
    def widen(mask):
        out = mask.copy()
        for k in range(-spread, spread + 1):
            out |= np.roll(mask, k)
        return out
    corner_w, slow_w = widen(corner), widen(slow)
    right_turn = np.sign(gaussian_filter1d(kappa, 6.0, mode="wrap")) > 0
    kerb = np.where(corner_w, 1.2, 0.0)
    runoff_l, runoff_r, wall_l, wall_r = [], [], [], []
    for i in range(n):
        outside_left = right_turn[i]  # a right-hander runs wide to the left
        for side in ("left", "right"):
            outside = (side == "left") == outside_left
            gravel = slow_w[i] and outside
            edge = (w_left if side == "left" else w_right)[i] + kerb[i]
            wall = edge + (24.0 if gravel else (9.0 if corner_w[i] else 6.0))
            (runoff_l if side == "left" else runoff_r).append("GRAVEL" if gravel else "GRASS")
            (wall_l if side == "left" else wall_r).append(wall)
    wall_l = list(np.maximum(gaussian_filter1d(np.array(wall_l), 4.0, mode="wrap"), w_left + kerb + 1.5))
    wall_r = list(np.maximum(gaussian_filter1d(np.array(wall_r), 4.0, mode="wrap"), w_right + kerb + 1.5))

    # --- Main straight, pit lane, grid, DRS, sectors -------------------------------------------
    # The start/finish line is TUM point 0. The main straight is the low-curvature run around it.
    straight = radius > 600.0
    a = 0
    while straight[(a - 1) % n] and a > -n:
        a -= 1
    b = 0
    while straight[(b + 1) % n] and b < n:
        b += 1
    straight_start_s = (s[a % n] - length) if a < 0 else s[a]
    straight_end_s = s[b % n]
    # The pit building sits on the inside (the right on a clockwise lap), behind a pit wall.
    pit_entry = (a - int(120.0 / (length / n))) % n
    pit_exit = (b - int(80.0 / (length / n))) % n
    pit_idx = []
    i = pit_entry
    while i != pit_exit:
        pit_idx.append(i)
        i = (i + 1) % n
    pit_offset = -(w_right + 9.0)
    pit_lane = [list(p[i] + normals[i] * pit_offset[i]) for i in pit_idx]
    for i in pit_idx[6:-6]:
        wall_r[i] = w_right[i] + kerb[i] + 1.5  # pit wall
    first_turn_right = right_turn[(b + 5) % n]
    grid = []
    spacing = length / n
    for k in range(24):
        back = 8.0 + 8.0 * k
        idx = int(round(-back / spacing)) % n
        side = (-1.0 if first_turn_right else 1.0) * (1.0 if k % 2 == 0 else -1.0)
        pos = p[idx] + normals[idx] * side * 2.3
        heading = math.atan2(tangents[idx][1], tangents[idx][0])
        grid.append({"x": float(pos[0]), "y": float(pos[1]), "heading": heading, "index": idx})
    drs_start = straight_start_s + 60.0
    drs_zones = [{"detection_s": (drs_start - 180.0) % length, "start_s": drs_start % length,
                  "end_s": (straight_end_s - 140.0) % length}]
    sectors = [length / 3.0, 2.0 * length / 3.0]

    line = racing_line(p, normals, w_left, w_right)

    # --- Environment ---------------------------------------------------------------------------
    track_tree = cKDTree(p)
    lake = ring_from_relation(rels[LAKE_RELATION], ways, nodes)
    trees = [list(nodes[nid]) for nid, t in node_tags.items() if t.get("natural") == "tree"]
    for tags, nd in ways.values():
        if tags.get("natural") == "tree_row":
            pts = [np.array(nodes[x]) for x in nd if x in nodes]
            for u, v in zip(pts, pts[1:]):
                steps = max(1, int(np.linalg.norm(v - u) / 9.0))
                trees += [list(u + (v - u) * (k / steps)) for k in range(steps)]
    trees = [t for t in trees if track_tree.query(t)[0] > 12.0]  # not on the asphalt
    buildings, parks = [], []
    for tags, nd in ways.values():
        if len(nd) < 4 or nd[0] != nd[-1]:
            continue
        pts = [nodes[x] for x in nd if x in nodes]
        if "building" in tags:
            c = np.mean(pts, axis=0)
            if track_tree.query(c)[0] < ENV_RADIUS:
                buildings.append({"footprint": [list(map(float, q)) for q in pts[:-1]], "height": building_height(tags)})
        elif tags.get("leisure") in ("park", "golf_course", "pitch") or tags.get("landuse") == "grass":
            parks.append({"kind": tags.get("leisure", tags.get("landuse")), "polygon": [list(map(float, q)) for q in pts[:-1]]})
    grandstands = []
    for i0, i1 in ((a + 10, a + 70), ((b + 2) % n, (b + 20) % n)):
        idxs = [k % n for k in range(i0, i1 if i1 > i0 else i1 + n)]
        side = 1.0  # outside of the main straight / T1 (left)
        grandstands.append({"polyline": [list(map(float, p[k] + normals[k] * side * (wall_l[k] + 4.0))) for k in idxs], "depth": 18.0})

    out = {
        "name": "Albert Park",
        "layout": "Grand Prix circuit 1996-2020",
        "origin_latlon": ORIGIN_LATLON,
        "length_m": length,
        "laps": 58,
        "direction": "clockwise",
        "points": p.tolist(),
        "heights": heights.tolist(),
        "width_left": w_left.tolist(),
        "width_right": w_right.tolist(),
        "kerb_left": kerb.tolist(),
        "kerb_right": kerb.tolist(),
        "kerb_high_left": [0] * n,
        "kerb_high_right": [0] * n,
        "runoff_left": runoff_l,
        "runoff_right": runoff_r,
        "wall_left": [float(v) for v in wall_l],
        "wall_right": [float(v) for v in wall_r],
        "racing_line": line.tolist(),
        "start_index": 0,
        "pit_lane": {"points": pit_lane, "entry_index": int(pit_entry), "exit_index": int(pit_exit), "speed_limit_kmh": 100},
        "grid": grid,
        "drs_zones": drs_zones,
        "sectors": sectors,
        "terrain": grid_out(grid_dem=grid_dict(dem)),
        "environment": {"lake": [list(map(float, q)) for q in lake], "trees": trees, "buildings": buildings,
                        "parks": parks, "grandstands": grandstands},
        "approximate": ["kerb_*", "runoff_*", "wall_*", "pit_lane", "grandstands", "drs_zones", "sectors"],
        "alignment_median_m": float(np.median(residual)),
        "sources": ["TUMFTM racetrack-database (LGPL-3.0)", "OpenStreetMap contributors (ODbL)",
                    "Copernicus DEM GLO-90 via Open-Meteo"],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, separators=(",", ":"))
    print(f"melbourne_2012.json: {n} points, {length:.1f} m, height {heights.min():.1f}-{heights.max():.1f} m, "
          f"{len(trees)} trees, {len(buildings)} buildings, alignment median {np.median(residual):.2f} m")


def grid_dict(dem):
    return {k: dem[k] for k in ("x0", "y0", "step", "nx", "ny", "heights")}


def grid_out(grid_dem):
    return grid_dem


if __name__ == "__main__":
    main()
