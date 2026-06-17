# driver_stats_game.py
# -*- coding: utf-8 -*-
import random
from sqlalchemy import text
from generate_order_drivers import engine  # mismo engine f1db

# Pool precargado para evitar ORDER BY RAND()
DRIVER_STATS_POOL = []

def warmup_driver_stats_pool(min_races: int = 20):
    global DRIVER_STATS_POOL
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT r.driverId
            FROM results r
            GROUP BY r.driverId
            HAVING COUNT(*) >= :minr
        """), {"minr": min_races}).fetchall()
    DRIVER_STATS_POOL = [int(r[0]) for r in rows]
    print("[startup] DriverStats pool:", len(DRIVER_STATS_POOL))

def pick_random_driver_id() -> int:
    if not DRIVER_STATS_POOL:
        warmup_driver_stats_pool()
    return random.choice(DRIVER_STATS_POOL)

def get_driver_name(driver_id: int) -> str:
    with engine.connect() as conn:
        row = conn.execute(text("""
            SELECT CONCAT(forename,' ',surname)
            FROM drivers
            WHERE driverId = :id
        """), {"id": driver_id}).fetchone()
    return row[0] if row else "Unknown"

def races_bin(races: int) -> str:
    if races >= 400: return "400+"
    if races >= 350: return "350-399"
    if races >= 300: return "300-349"
    if races >= 250: return "250-299"
    if races >= 200: return "200-249"
    if races >= 150: return "150-199"
    if races >= 100: return "100-149"
    if races >= 50:  return "50-99"
    return "0-49"

def points_bin(points: float) -> str:
    if points >= 3000: return "3000+"
    if points >= 2000: return "2000-2999"
    if points >= 1500: return "1500-1999"
    if points >= 1000: return "1000-1499"
    if points >= 500:  return "500-999"
    if points >= 300:  return "300-499"
    if points >= 100:  return "100-299"
    return "0-99"

def count_titles(driver_id: int) -> int:
    with engine.connect() as conn:
        row = conn.execute(text("""
            SELECT COUNT(*) AS titles
            FROM driverStandings ds
            JOIN races r ON r.raceId = ds.raceId
            JOIN (
              SELECT year, MAX(round) AS maxRound
              FROM races
              GROUP BY year
            ) lastRace ON lastRace.year = r.year AND lastRace.maxRound = r.round
            WHERE ds.driverId = :driverId
              AND ds.position = 1
        """), {"driverId": driver_id}).fetchone()
    return int(row[0]) if row and row[0] is not None else 0

def get_real_stats(driver_id: int):
    with engine.connect() as conn:
        row = conn.execute(text("""
            SELECT
              SUM(CASE WHEN r.positionOrder = 1 THEN 1 ELSE 0 END) AS wins,
              SUM(CASE WHEN r.positionOrder IN (1,2,3) THEN 1 ELSE 0 END) AS podiums,
              COUNT(*) AS races,
              COUNT(DISTINCT r.constructorId) AS teams,
              COALESCE(SUM(r.points),0) AS points,
              COUNT(DISTINCT ra.year) AS seasons
            FROM results r
            JOIN races ra ON ra.raceId = r.raceId
            WHERE r.driverId = :driverId
        """), {"driverId": driver_id}).fetchone()

    wins = int(row[0] or 0)
    podiums = int(row[1] or 0)
    races = int(row[2] or 0)
    teams = int(row[3] or 0)
    points = float(row[4] or 0.0)
    seasons = int(row[5] or 0)
    titles = count_titles(driver_id)

    return {
        "wins": wins,
        "podiums": podiums,
        "races": races,
        "teams": teams,
        "points": points,
        "seasons": seasons,
        "titles": titles,
        "racesBin": races_bin(races),
        "pointsBin": points_bin(points),
    }

def generate_driver_stats_game(lang="es"):
    driver_id = pick_random_driver_id()
    name = get_driver_name(driver_id)
    return {"driverId": driver_id, "driverName": name}

def _label(key: str, lang: str) -> str:
    es = {
        "wins": "Victorias",
        "podiums": "Podios",
        "teams": "Número de equipos",
        "races": "Carreras (aprox.)",
        "titles": "Campeonatos del mundo",
        "points": "Puntos (aprox.)",
        "seasons": "Temporadas",
    }
    en = {
        "wins": "Wins",
        "podiums": "Podiums",
        "teams": "Number of teams",
        "races": "Races (approx.)",
        "titles": "World championships",
        "points": "Points (approx.)",
        "seasons": "Seasons",
    }
    return (es if lang == "es" else en)[key]

# ✅ Normalizadores para evitar comparaciones "7" (str) vs 7 (int)
def _as_int(v):
    try:
        if v is None:
            return None
        # ya es int/bool/float, etc.
        if isinstance(v, bool):
            # por si acaso alguien manda true/false: no tiene sentido aquí
            return None
        return int(v)
    except Exception:
        return None

def _as_str(v):
    if v is None:
        return None
    try:
        return str(v)
    except Exception:
        return None

def validate_driver_stats(driver_id: int, answers: dict, lang="es"):
    """
    answers esperado (ideal):
      {
        "wins": int,
        "podiums": int,
        "teams": int,
        "titles": int,
        "seasons": int,
        "racesBin": "50-99" | ...,
        "pointsBin": "300-499" | ...
      }

    ✅ Robusto: si llega como string (e.g. "7"), lo convierte y compara bien.
    """
    real = get_real_stats(driver_id)

    details = []
    correct = 0

    def add_detail(label_key, user_val, actual_val, ok):
        nonlocal correct
        if ok:
            correct += 1
        details.append({
            "label": _label(label_key, lang),
            "user": str(user_val) if user_val is not None else "-",
            "actual": str(actual_val) if actual_val is not None else "-",
            "correct": bool(ok),
        })

    # Exactos (normalizados a int)
    uw = _as_int(answers.get("wins"))
    up = _as_int(answers.get("podiums"))
    ut = _as_int(answers.get("teams"))
    utitle = _as_int(answers.get("titles"))
    useasons = _as_int(answers.get("seasons"))

    add_detail("wins", uw, real["wins"], uw is not None and uw == real["wins"])
    add_detail("podiums", up, real["podiums"], up is not None and up == real["podiums"])
    add_detail("teams", ut, real["teams"], ut is not None and ut == real["teams"])
    add_detail("titles", utitle, real["titles"], utitle is not None and utitle == real["titles"])
    add_detail("seasons", useasons, real["seasons"], useasons is not None and useasons == real["seasons"])

    # Aproximados (bins) -> string
    uraces_bin = _as_str(answers.get("racesBin"))
    upoints_bin = _as_str(answers.get("pointsBin"))

    add_detail("races", uraces_bin, real["racesBin"], uraces_bin is not None and uraces_bin == real["racesBin"])
    add_detail("points", upoints_bin, real["pointsBin"], upoints_bin is not None and upoints_bin == real["pointsBin"])

    return {"correctCount": correct, "details": details}
