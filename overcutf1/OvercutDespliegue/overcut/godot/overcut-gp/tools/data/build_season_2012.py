"""Builds data/seasons/2012.json from f1db (CC BY 4.0) plus hand-researched visual data.

f1db gives the calendar, entrants, chassis, engines, drivers, numbers and every qualifying and
race result. Team liveries (colours only, no sponsors) and chassis shape parameters are not in
any dataset: they are set here from the cars' public photos and technical descriptions.
Run: python -I tools/data/build_season_2012.py
"""
import csv
import json
import math
import os
from collections import defaultdict

HERE = os.path.dirname(os.path.abspath(__file__))
RAW = os.path.join(HERE, "raw", "f1db")
OUT = os.path.join(HERE, "..", "..", "data", "seasons", "2012.json")
YEAR = "2012"
AVAILABLE = {"australia"}

# Liveries (main body, secondary, accent) — colours only, as the cars looked in 2012.
# Chassis shape (metres): wheelbase, nose step height at the 550 mm line (0 = smooth nose),
# nose tip height, sidepod length, and whether the engine cover carries a shark fin.
TEAMS = {
    "red-bull":    {"colors": ("#1B2A5C", "#C8102E", "#F4C300"), "wheelbase": 3.30, "nose_step": 0.08, "nose_tip": 0.30, "sidepod": 1.45, "fin": False},
    "mclaren":     {"colors": ("#B9BEC4", "#E10600", "#2B2B2B"), "wheelbase": 3.40, "nose_step": 0.00, "nose_tip": 0.24, "sidepod": 1.55, "fin": False},
    "ferrari":     {"colors": ("#D40000", "#FFFFFF", "#111111"), "wheelbase": 3.30, "nose_step": 0.12, "nose_tip": 0.28, "sidepod": 1.50, "fin": False},
    "mercedes":    {"colors": ("#B4BBC2", "#00A19C", "#1A1A1A"), "wheelbase": 3.45, "nose_step": 0.07, "nose_tip": 0.27, "sidepod": 1.60, "fin": True},
    "lotus-f1":    {"colors": ("#141414", "#C9A54A", "#C9A54A"), "wheelbase": 3.30, "nose_step": 0.10, "nose_tip": 0.27, "sidepod": 1.45, "fin": False},
    "force-india": {"colors": ("#F2F2F2", "#F7941D", "#2E8B3E"), "wheelbase": 3.30, "nose_step": 0.12, "nose_tip": 0.27, "sidepod": 1.50, "fin": True},
    "sauber":      {"colors": ("#F2F2F2", "#1A1A1A", "#7A8A99"), "wheelbase": 3.35, "nose_step": 0.11, "nose_tip": 0.27, "sidepod": 1.45, "fin": False},
    "toro-rosso":  {"colors": ("#1C2A6B", "#C0C4CC", "#C8102E"), "wheelbase": 3.30, "nose_step": 0.10, "nose_tip": 0.28, "sidepod": 1.40, "fin": False},
    "williams":    {"colors": ("#0B2346", "#F2F2F2", "#6EA8DC"), "wheelbase": 3.30, "nose_step": 0.10, "nose_tip": 0.27, "sidepod": 1.40, "fin": False},
    "caterham":    {"colors": ("#0B5B3A", "#F5D100", "#111111"), "wheelbase": 3.30, "nose_step": 0.15, "nose_tip": 0.28, "sidepod": 1.50, "fin": True},
    "hrt":         {"colors": ("#F2F2F2", "#B8001F", "#7C7C7C"), "wheelbase": 3.25, "nose_step": 0.06, "nose_tip": 0.30, "sidepod": 1.50, "fin": True},
    "marussia":    {"colors": ("#141414", "#B0102A", "#FFFFFF"), "wheelbase": 3.30, "nose_step": 0.10, "nose_tip": 0.28, "sidepod": 1.50, "fin": True},
}
# Helmet colours (main, stripe) — the designs drivers raced with in 2012, simplified.
HELMETS = {
    "VET": ("#FFFFFF", "#1E3A8A"), "WEB": ("#F2F2F2", "#1B2A5C"), "BUT": ("#FFFFFF", "#E5007E"),
    "HAM": ("#F5D100", "#1B6E2F"), "ALO": ("#1E3A8A", "#F5D100"), "MAS": ("#FFFFFF", "#2E8B3E"),
    "MSC": ("#D40000", "#FFFFFF"), "ROS": ("#F5F5F5", "#00A19C"), "RAI": ("#FFFFFF", "#C8102E"),
    "GRO": ("#FFFFFF", "#111111"), "DAM": ("#E9E9E9", "#1E3A8A"), "DIR": ("#1E3A8A", "#FFFFFF"),
    "HUL": ("#F5D100", "#111111"), "KOB": ("#FFFFFF", "#D40000"), "PER": ("#FFFFFF", "#2E8B3E"),
    "RIC": ("#FFFFFF", "#D40000"), "VER": ("#1E3A8A", "#FFFFFF"), "MAL": ("#F5D100", "#D40000"),
    "SEN": ("#F5D100", "#2E8B3E"), "KOV": ("#FFFFFF", "#1E3A8A"), "PET": ("#FFFFFF", "#D40000"),
    "DLR": ("#F5D100", "#D40000"), "KAR": ("#F2F2F2", "#FF8C00"), "GLO": ("#FFFFFF", "#111111"),
    "PIC": ("#1E3A8A", "#FFFFFF"),
}
TEAM_NAMES = {"red-bull": "Red Bull Racing", "mclaren": "McLaren", "ferrari": "Ferrari", "mercedes": "Mercedes",
              "lotus-f1": "Lotus", "force-india": "Force India", "sauber": "Sauber", "toro-rosso": "Toro Rosso",
              "williams": "Williams", "caterham": "Caterham", "hrt": "HRT", "marussia": "Marussia"}


def rows(name):
    with open(os.path.join(RAW, f"f1db-{name}.csv"), encoding="utf-8") as f:
        return list(csv.DictReader(f))


def ms(row, *keys):
    vals = [int(row[k]) for k in keys if row.get(k)]
    return min(vals) if vals else None


def main():
    races = [r for r in rows("races") if r["year"] == YEAR]
    races.sort(key=lambda r: int(r["round"]))
    race_by_id = {r["id"]: r for r in races}
    drivers = {d["id"]: d for d in rows("drivers")}
    chassis = {c["id"]: c for c in rows("chassis")}
    engines = {e["id"]: e for e in rows("engine-manufacturers")}
    ent_chassis = {r["constructorId"]: r["chassisId"] for r in rows("seasons-entrants-chassis") if r["year"] == YEAR}
    ent_drivers = [r for r in rows("seasons-entrants-drivers") if r["year"] == YEAR and r["testDriver"] == "false"]
    quali = [r for r in rows("races-qualifying-results") if r["raceId"] in race_by_id]
    results = [r for r in rows("races-race-results") if r["raceId"] in race_by_id]

    number = {}
    for r in results:
        number.setdefault(r["driverId"], int(r["driverNumber"]))

    teams = []
    for cid, spec in TEAMS.items():
        engine = next(r["engineManufacturerId"] for r in ent_drivers if r["constructorId"] == cid)
        ch = ent_chassis[cid]
        teams.append({
            "id": cid, "name": TEAM_NAMES[cid], "chassis": chassis[ch]["name"], "engine": engines[engine]["name"],
            "colors": dict(zip(("primary", "secondary", "accent"), spec["colors"])),
            "car": {k: spec[k] for k in ("wheelbase", "nose_step", "nose_tip", "sidepod", "fin")},
        })

    out_drivers = []
    for r in ent_drivers:
        d = drivers[r["driverId"]]
        code = d["abbreviation"]
        rounds = [int(x) for x in r["rounds"].split(";") if x]
        out_drivers.append({
            "id": d["id"], "code": code, "name": d["name"], "first_name": d["firstName"], "last_name": d["lastName"],
            "number": number.get(d["id"]), "team": r["constructorId"], "rounds": rounds,
            "starter": 1 in rounds, "helmet": dict(zip(("main", "stripe"), HELMETS.get(code, ("#FFFFFF", "#111111")))),
        })

    # Team pace per GP: best qualifying lap of the team relative to the fastest team (in %).
    pace = {}
    for race in races:
        best = {}
        for q in quali:
            if q["raceId"] != race["id"]:
                continue
            t = ms(q, "q1Millis", "q2Millis", "q3Millis", "timeMillis")
            if t:
                best[q["constructorId"]] = min(best.get(q["constructorId"], t), t)
        if best:
            top = min(best.values())
            pace[race["grandPrixId"]] = {c: (v / top - 1.0) * 100.0 for c, v in best.items()}

    # Driver vs team-mate in qualifying (the only car-neutral number): mean % gap over the season,
    # compared in the last session both drivers took part in.
    gaps = defaultdict(list)
    for race in races:
        by_team = defaultdict(list)
        for q in quali:
            if q["raceId"] == race["id"]:
                by_team[q["constructorId"]].append(q)
        for team, pair in by_team.items():
            if len(pair) != 2:
                continue
            for key in ("q3Millis", "q2Millis", "q1Millis"):
                a, b = pair[0].get(key), pair[1].get(key)
                if a and b:
                    a, b = int(a), int(b)
                    gaps[pair[0]["driverId"]].append((a / b - 1.0) * 100.0)
                    gaps[pair[1]["driverId"]].append((b / a - 1.0) * 100.0)
                    break
    for d in out_drivers:
        g = sorted(gaps.get(d["id"], []))
        # median keeps one wet or crashed session from defining a driver
        d["quali_vs_teammate_pct"] = g[len(g) // 2] if g else 0.0
        d["quali_sessions"] = len(g)

    # Mechanical retirements per car-race (accidents and collisions are the race's business).
    not_mechanical = {"Collision", "Collision damage", "Accident", "Spun off", "Illness", "Puncture", "Puncture damage"}
    starts = defaultdict(int)
    failures = defaultdict(int)
    for r in results:
        if r["positionText"] in ("DNQ", "DNPQ", "EX", "DNS"):
            continue
        starts[r["constructorId"]] += 1
        if r["reasonRetired"] and r["reasonRetired"] not in not_mechanical:
            failures[r["constructorId"]] += 1
    for t in teams:
        n = starts.get(t["id"], 0)
        # a little prior so a lucky season does not read as bullet-proof
        t["mechanical_dnf_rate"] = round((failures.get(t["id"], 0) + 0.5) / (n + 5), 4)

    real = {}
    code_of = {d["id"]: d["abbreviation"] for d in drivers.values()}
    for race in races:
        if race["grandPrixId"] not in AVAILABLE:
            continue
        q = sorted([r for r in quali if r["raceId"] == race["id"]], key=lambda r: int(r["positionDisplayOrder"]))
        rr = sorted([r for r in results if r["raceId"] == race["id"]], key=lambda r: int(r["positionDisplayOrder"]))
        real[race["grandPrixId"]] = {
            "qualifying": [{"code": code_of[r["driverId"]], "team": r["constructorId"], "position": r["positionText"],
                            "q1": r["q1"], "q2": r["q2"], "q3": r["q3"],
                            "best_s": ms(r, "q1Millis", "q2Millis", "q3Millis") / 1000.0 if ms(r, "q1Millis", "q2Millis", "q3Millis") else None} for r in q],
            "race": [{"code": code_of[r["driverId"]], "position": r["positionText"], "laps": int(r["laps"]) if r["laps"] else 0,
                      "time": r["time"], "retired": r["reasonRetired"], "grid": r["gridPositionText"], "pit_stops": r["pitStops"]} for r in rr],
        }

    out = {
        "year": 2012,
        "points": [25, 18, 15, 12, 10, 8, 6, 4, 2, 1],
        "fastest_lap_point": False,
        "qualifying_format": "Q1Q2Q3",
        "tyre_supplier": "Pirelli",
        "calendar": [{"round": int(r["round"]), "id": r["grandPrixId"], "date": r["date"], "circuit": r["circuitId"],
                      "laps": int(r["laps"]), "length_km": float(r["courseLength"]), "available": r["grandPrixId"] in AVAILABLE}
                     for r in races],
        "teams": teams,
        "drivers": out_drivers,
        "pace": pace,
        "real_results": real,
        "sources": ["f1db (CC BY 4.0)", "liveries and chassis shapes: hand-researched from public photos"],
    }
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    with open(OUT, "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, indent=1)
    print(f"2012.json: {len(out['calendar'])} GP, {len(teams)} teams, {sum(d['starter'] for d in out_drivers)} starters")


if __name__ == "__main__":
    main()
