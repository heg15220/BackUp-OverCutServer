# -*- coding: utf-8 -*-
import random
import unicodedata
from time import time
from sqlalchemy import text
from generate_order_drivers import engine  # ya lo usas en tu ecosistema

THEME_TYPES = [
    "WINNERS_AT_CIRCUIT",
    "PODIUM_AT_CIRCUIT",
    "WINNERS_FOR_TEAM",
    "PODIUM_FOR_TEAM",
    "RACED_FOR_TEAM",
    "TEAMMATES_OF_DRIVER",
    "NATIONALITY",
]

# =========================
# Normalización robusta
# =========================
def norm(s: str) -> str:
    s = (s or "").strip().lower()
    # quita acentos/diacríticos
    s = unicodedata.normalize("NFKD", s)
    s = "".join(ch for ch in s if not unicodedata.combining(ch))
    # colapsa espacios
    s = " ".join(s.split())
    return s


# =========================
# Pools precargados (evitar ORDER BY RAND)
# =========================
CIRCUITS_POOL: list[str] = []
TEAMS_POOL: list[str] = []
NATS_POOL: list[str] = []
DRIVERS_POOL: list[str] = []

def warmup_30s_pools():
    """
    Se ejecuta 1 vez al arrancar FastAPI.
    Carga listas "válidas" para elegir tema sin consultas pesadas ni RAND.
    """
    global CIRCUITS_POOL, TEAMS_POOL, NATS_POOL, DRIVERS_POOL
    with engine.connect() as conn:
        CIRCUITS_POOL = [r[0] for r in conn.execute(text("""
            SELECT c.name
            FROM circuits c
            JOIN races r ON r.circuitId = c.circuitId
            GROUP BY c.circuitId, c.name
            HAVING COUNT(*) >= 8
        """)).fetchall()]

        TEAMS_POOL = [r[0] for r in conn.execute(text("""
            SELECT c.name
            FROM constructors c
            JOIN results r ON r.constructorId = c.constructorId
            JOIN races ra ON ra.raceId = r.raceId
            GROUP BY c.constructorId, c.name
            HAVING COUNT(*) >= 300
        """)).fetchall()]

        NATS_POOL = [r[0] for r in conn.execute(text("""
            SELECT d.nationality
            FROM drivers d
            WHERE d.nationality IS NOT NULL
            GROUP BY d.nationality
            HAVING COUNT(*) >= 10
        """)).fetchall()]

        DRIVERS_POOL = [r[0] for r in conn.execute(text("""
            SELECT CONCAT(d.forename,' ',d.surname)
            FROM drivers d
            JOIN results r ON r.driverId = d.driverId
            JOIN races ra ON ra.raceId = r.raceId
            GROUP BY d.driverId
            HAVING COUNT(*) >= 80
        """)).fetchall()]

    print(
        f"[startup] 30s pools: "
        f"circuits={len(CIRCUITS_POOL)} teams={len(TEAMS_POOL)} "
        f"nats={len(NATS_POOL)} drivers={len(DRIVERS_POOL)}"
    )


def _rand_from(pool: list[str], fallback: str = "") -> str:
    if not pool:
        return fallback
    return random.choice(pool)


def generate_30_seconds_theme(lang: str = "es"):
    """
    Genera tema rápido (O(1)).
    """
    t = random.choice(THEME_TYPES)

    if t in ("WINNERS_AT_CIRCUIT", "PODIUM_AT_CIRCUIT"):
        value = _rand_from(CIRCUITS_POOL)
    elif t in ("WINNERS_FOR_TEAM", "PODIUM_FOR_TEAM", "RACED_FOR_TEAM"):
        value = _rand_from(TEAMS_POOL)
    elif t == "TEAMMATES_OF_DRIVER":
        value = _rand_from(DRIVERS_POOL)
    else:
        value = _rand_from(NATS_POOL)

    return {"themeType": t, "themeValue": value}


# =========================
# Cache de sets válidos por tema (para acelerar /validate)
# =========================
VALID_CACHE: dict[tuple[str, str], tuple[float, set[str]]] = {}
VALID_TTL_SECONDS = 60 * 60  # 1 hora


def _valid_set(themeType: str, themeValue: str) -> set[str]:
    """
    Devuelve el set de pilotos válidos (normalizado) para la temática.
    Cacheado para evitar queries repetidas.
    """
    tv = (themeValue or "").strip()
    key = (themeType, norm(tv))
    now = time()

    hit = VALID_CACHE.get(key)
    if hit and (now - hit[0] < VALID_TTL_SECONDS):
        return hit[1]

    with engine.connect() as conn:
        if themeType == "WINNERS_AT_CIRCUIT":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM results r
                JOIN races ra ON ra.raceId = r.raceId
                JOIN circuits c ON c.circuitId = ra.circuitId
                JOIN drivers d ON d.driverId = r.driverId
                WHERE c.name = :circuit
                  AND r.position = 1
            """), {"circuit": tv}).fetchall()

        elif themeType == "PODIUM_AT_CIRCUIT":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM results r
                JOIN races ra ON ra.raceId = r.raceId
                JOIN circuits c ON c.circuitId = ra.circuitId
                JOIN drivers d ON d.driverId = r.driverId
                WHERE c.name = :circuit
                  AND r.position IN (1,2,3)
            """), {"circuit": tv}).fetchall()

        elif themeType == "WINNERS_FOR_TEAM":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM results r
                JOIN drivers d ON d.driverId = r.driverId
                JOIN constructors c ON c.constructorId = r.constructorId
                WHERE c.name = :team
                  AND r.position = 1
            """), {"team": tv}).fetchall()

        elif themeType == "PODIUM_FOR_TEAM":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM results r
                JOIN drivers d ON d.driverId = r.driverId
                JOIN constructors c ON c.constructorId = r.constructorId
                WHERE c.name = :team
                  AND r.position IN (1,2,3)
            """), {"team": tv}).fetchall()

        elif themeType == "RACED_FOR_TEAM":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM results r
                JOIN drivers d ON d.driverId = r.driverId
                JOIN constructors c ON c.constructorId = r.constructorId
                WHERE c.name = :team
            """), {"team": tv}).fetchall()

        elif themeType == "TEAMMATES_OF_DRIVER":
            # Teammates: mismo raceId + constructorId, distinto driverId
            # ojo: aquí themeValue viene como nombre del piloto
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d2.forename,' ',d2.surname)) AS name
                FROM results r1
                JOIN drivers d1 ON d1.driverId = r1.driverId
                JOIN results r2 ON r2.raceId = r1.raceId
                             AND r2.constructorId = r1.constructorId
                             AND r2.driverId <> r1.driverId
                JOIN drivers d2 ON d2.driverId = r2.driverId
                WHERE LOWER(CONCAT(d1.forename,' ',d1.surname)) = LOWER(:driverName)
            """), {"driverName": tv}).fetchall()

        elif themeType == "NATIONALITY":
            rows = conn.execute(text("""
                SELECT DISTINCT LOWER(CONCAT(d.forename,' ',d.surname)) AS name
                FROM drivers d
                WHERE d.nationality = :nat
            """), {"nat": tv}).fetchall()

        else:
            rows = []

    valid = {norm(r[0]) for r in rows if r and r[0]}
    VALID_CACHE[key] = (now, valid)
    return valid


def validate_30_seconds(themeType: str, themeValue: str, answers: list[str]):
    """
    Valida answers contra la temática.
    - Únicos case/accent-insensitive manteniendo orden
    - Respuesta: {correctCount, results:[{answer, valid}]}
    """
    valid = _valid_set(themeType, themeValue)

    # únicos case/accent-insensitive manteniendo orden
    seen = set()
    normalized_original = []
    for a in answers or []:
        s = (a or "").strip()
        if not s:
            continue
        k = norm(s)
        if k in seen:
            continue
        seen.add(k)
        normalized_original.append(s)

    results = []
    correct = 0
    for a in normalized_original:
        ok = norm(a) in valid
        if ok:
            correct += 1
        results.append({"answer": a, "valid": ok})

    return {"correctCount": correct, "results": results}
