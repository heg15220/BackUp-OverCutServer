"""Downloads the open data the builders need into tools/data/raw/ (not versioned).
Run: python -I tools/data/fetch_sources.py   then build_melbourne.py and build_season_2012.py
"""
import io
import json
import math
import os
import time
import urllib.request
import zipfile

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw")
UA = {"User-Agent": "OverCutGP/0.1 (game track research)"}
ORIGIN_LATLON = (-37.8497, 144.9680)
# OSM API caps a map call at 50k nodes, so Albert Park comes in four tiles.
OSM_TILES = ["144.9560,-37.8660,144.9690,-37.8500", "144.9560,-37.8500,144.9690,-37.8340",
             "144.9690,-37.8660,144.9820,-37.8500", "144.9690,-37.8500,144.9820,-37.8340"]
# DEM grid in local metres (x east, y south) covering the park with a 400 m margin.
DEM_X0, DEM_Y0, DEM_STEP, DEM_NX, DEM_NY = -913.888295, -1696.424196, 60.0, 38, 43


def get(url, binary=True):
    req = urllib.request.Request(url, headers=UA)
    wait = 15
    for _ in range(10):
        try:
            data = urllib.request.urlopen(req, timeout=120).read()
            return data if binary else data.decode("utf-8")
        except Exception as e:  # rate limits and busy mirrors are routine here
            print("retry in", wait, "s:", e, flush=True)
            time.sleep(wait)
            wait = min(wait * 2, 120)
    raise SystemExit("download failed: " + url)


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


def latlon(x, y):
    lat0, lon0 = ORIGIN_LATLON
    return lat0 - y / 110574.0, lon0 + x / (111320.0 * math.cos(math.radians(lat0)))


def main():
    for bbox in OSM_TILES:
        save(os.path.join(RAW, "osm", "map_%s.osm" % bbox.replace(",", "_").replace(".", "_")),
             get("https://api.openstreetmap.org/api/0.6/map?bbox=" + bbox))
    base = "https://raw.githubusercontent.com/TUMFTM/racetrack-database/master/"
    save(os.path.join(RAW, "osm", "tum_melbourne.csv"), get(base + "tracks/Melbourne.csv"))
    save(os.path.join(RAW, "osm", "tum_LICENSE"), get(base + "LICENSE"))
    pts = [latlon(DEM_X0 + i * DEM_STEP, DEM_Y0 + j * DEM_STEP) for j in range(DEM_NY) for i in range(DEM_NX)]
    heights = []
    for k in range(0, len(pts), 100):
        chunk = pts[k:k + 100]
        url = "https://api.open-meteo.com/v1/elevation?latitude=%s&longitude=%s" % (
            ",".join("%.6f" % p[0] for p in chunk), ",".join("%.6f" % p[1] for p in chunk))
        heights += json.loads(get(url, binary=False))["elevation"]
        time.sleep(4)
    assert len(heights) == len(pts)
    save(os.path.join(RAW, "osm", "albert_park_elevation.json"), json.dumps(
        {"x0": DEM_X0, "y0": DEM_Y0, "step": DEM_STEP, "nx": DEM_NX, "ny": DEM_NY, "heights": heights,
         "source": "Copernicus DEM GLO-90 via Open-Meteo elevation API"}).encode())
    z = zipfile.ZipFile(io.BytesIO(get("https://github.com/f1db/f1db/releases/latest/download/f1db-csv.zip")))
    for name in z.namelist():
        if name.endswith(".csv"):
            save(os.path.join(RAW, "f1db", os.path.basename(name)), z.read(name))
    print("sources downloaded to", RAW)


if __name__ == "__main__":
    main()
