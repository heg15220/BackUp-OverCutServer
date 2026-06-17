# generate_driver_season_game.py
import os
import random
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DB_URL = os.getenv("DB_URI", "mysql+pymysql://root:root@db:3306/f1db")
engine = create_engine(DB_URL, pool_pre_ping=True)
Session = sessionmaker(bind=engine)

GRAND_PRIX_TRANSLATIONS = {
    "70th Anniversary Grand Prix": "Gran Premio 70.º Aniversario",
    "Abu Dhabi Grand Prix": "Gran Premio de Abu Dabi",
    "Argentine Grand Prix": "Gran Premio de Argentina",
    "Australian Grand Prix": "Gran Premio de Australia",
    "Austrian Grand Prix": "Gran Premio de Austria",
    "Azerbaijan Grand Prix": "Gran Premio de Azerbaiyán",
    "Bahrain Grand Prix": "Gran Premio de Baréin",
    "Belgian Grand Prix": "Gran Premio de Bélgica",
    "Brazilian Grand Prix": "Gran Premio de Brasil",
    "British Grand Prix": "Gran Premio de Gran Bretaña",
    "Caesars Palace Grand Prix": "Gran Premio del Caesars Palace",
    "Canadian Grand Prix": "Gran Premio de Canadá",
    "Chinese Grand Prix": "Gran Premio de China",
    "Dallas Grand Prix": "Gran Premio de Dallas",
    "Detroit Grand Prix": "Gran Premio de Detroit",
    "Dutch Grand Prix": "Gran Premio de los Países Bajos",
    "Eifel Grand Prix": "Gran Premio de Eifel",
    "Emilia Romagna Grand Prix": "Gran Premio de Emilia-Romaña",
    "European Grand Prix": "Gran Premio de Europa",
    "French Grand Prix": "Gran Premio de Francia",
    "German Grand Prix": "Gran Premio de Alemania",
    "Hungarian Grand Prix": "Gran Premio de Hungría",
    "Indian Grand Prix": "Gran Premio de la India",
    "Indianapolis 500": "500 Millas de Indianápolis",
    "Italian Grand Prix": "Gran Premio de Italia",
    "Japanese Grand Prix": "Gran Premio de Japón",
    "Korean Grand Prix": "Gran Premio de Corea",
    "Las Vegas Grand Prix": "Gran Premio de Las Vegas",
    "Luxembourg Grand Prix": "Gran Premio de Luxemburgo",
    "Malaysian Grand Prix": "Gran Premio de Malasia",
    "Mexican Grand Prix": "Gran Premio de México",
    "Mexico City Grand Prix": "Gran Premio de Ciudad de México",
    "Miami Grand Prix": "Gran Premio de Miami",
    "Monaco Grand Prix": "Gran Premio de Mónaco",
    "Moroccan Grand Prix": "Gran Premio de Marruecos",
    "Pacific Grand Prix": "Gran Premio del Pacífico",
    "Pescara Grand Prix": "Gran Premio de Pescara",
    "Portuguese Grand Prix": "Gran Premio de Portugal",
    "Qatar Grand Prix": "Gran Premio de Catar",
    "Russian Grand Prix": "Gran Premio de Rusia",
    "Sakhir Grand Prix": "Gran Premio de Sakhir",
    "San Marino Grand Prix": "Gran Premio de San Marino",
    "São Paulo Grand Prix": "Gran Premio de São Paulo",
    "Saudi Arabian Grand Prix": "Gran Premio de Arabia Saudita",
    "Singapore Grand Prix": "Gran Premio de Singapur",
    "South African Grand Prix": "Gran Premio de Sudáfrica",
    "Spanish Grand Prix": "Gran Premio de España",
    "Styrian Grand Prix": "Gran Premio de Estiria",
    "Swedish Grand Prix": "Gran Premio de Suecia",
    "Swiss Grand Prix": "Gran Premio de Suiza",
    "Turkish Grand Prix": "Gran Premio de Turquía",
    "Tuscan Grand Prix": "Gran Premio de la Toscana",
    "United States Grand Prix": "Gran Premio de Estados Unidos",
    "United States Grand Prix West": "Gran Premio del Oeste de Estados Unidos",
}

def translate_gp_name(en_name: str) -> str:
    if not en_name:
        return en_name
    en_name = en_name.strip()
    return GRAND_PRIX_TRANSLATIONS.get(en_name, en_name)

# ==========================================================
# ✅ POOLS EN MEMORIA
# ==========================================================
DRIVER_WITH_2_PODIUMS_POOL: list[int] = []
DRIVER_SEASONS_CACHE: dict[int, list[int]] = {}

def warmup_driver_season_pools(min_year: int = 1950):
    """
    - Precarga drivers con >=2 podios
    - Precarga, para cada driver, la lista de temporadas donde tiene resultados válidos
    Evita ORDER BY RAND() en results/races.
    """
    global DRIVER_WITH_2_PODIUMS_POOL, DRIVER_SEASONS_CACHE

    session = Session()
    try:
        # Drivers con >=2 podios
        rows = session.execute(text("""
            SELECT res.driverId
            FROM results res
            WHERE res.positionOrder <= 3
            GROUP BY res.driverId
            HAVING COUNT(*) >= 2
        """)).fetchall()
        DRIVER_WITH_2_PODIUMS_POOL = [int(r[0]) for r in rows]
        random.shuffle(DRIVER_WITH_2_PODIUMS_POOL)

        # Temporadas por driver (solo posiciones numéricas)
        # Importante: esto puede ser grande, pero suele ser manejable en RAM para f1db
        rows2 = session.execute(text("""
            SELECT res.driverId, r.year
            FROM results res
            JOIN races r ON r.raceId = res.raceId
            WHERE r.year >= :min_year
              AND res.positionOrder IS NOT NULL
              AND res.positionText REGEXP '^[0-9]+$'
            GROUP BY res.driverId, r.year
        """), {"min_year": min_year}).fetchall()

        tmp: dict[int, set[int]] = {}
        for driver_id, year in rows2:
            did = int(driver_id)
            y = int(year)
            tmp.setdefault(did, set()).add(y)

        DRIVER_SEASONS_CACHE = {did: sorted(list(years)) for did, years in tmp.items()}

        print(f"[startup] DriverSeason pools cargados: "
              f"drivers>=2podios={len(DRIVER_WITH_2_PODIUMS_POOL)}, "
              f"drivers con seasons={len(DRIVER_SEASONS_CACHE)}")
    finally:
        session.close()

def _pick_driver_with_2_podiums() -> int:
    if not DRIVER_WITH_2_PODIUMS_POOL:
        warmup_driver_season_pools()
    if not DRIVER_WITH_2_PODIUMS_POOL:
        raise RuntimeError("No hay drivers con >=2 podios (pool vacío).")
    return random.choice(DRIVER_WITH_2_PODIUMS_POOL)

def _pick_random_season_for_driver(driver_id: int) -> int:
    years = DRIVER_SEASONS_CACHE.get(int(driver_id)) or []
    if not years:
        # fallback: recalentar (por si se cargó sin ese driver por algún filtro)
        warmup_driver_season_pools()
        years = DRIVER_SEASONS_CACHE.get(int(driver_id)) or []
    if not years:
        raise RuntimeError(f"No hay temporadas válidas para driverId={driver_id}.")
    return random.choice(years)

def _get_driver_name(session, driver_id: int) -> str:
    row = session.execute(text("""
        SELECT CONCAT(d.forename, ' ', d.surname) AS full_name
        FROM drivers d
        WHERE d.driverId = :driver_id
        LIMIT 1
    """), {"driver_id": driver_id}).fetchone()
    return (row[0] if row and row[0] else "").strip()

def _max_position_for_season(session, year: int) -> int:
    max_pos = session.execute(text("""
        SELECT MAX(res.positionOrder)
        FROM results res
        JOIN races r ON r.raceId = res.raceId
        WHERE r.year = :year
          AND res.positionOrder IS NOT NULL
          AND res.positionText REGEXP '^[0-9]+$'
    """), {"year": year}).scalar() or 20
    return int(max_pos)

def get_driver_season_game():
    session = Session()
    try:
        driver_id = _pick_driver_with_2_podiums()
        driver_name = _get_driver_name(session, driver_id)
        year = _pick_random_season_for_driver(driver_id)

        rows = session.execute(text("""
            SELECT
              r.raceId,
              r.round,
              r.name AS race_name_en,
              c.country AS country,
              res.positionOrder AS finishing_position
            FROM results res
            JOIN races r ON r.raceId = res.raceId
            JOIN circuits c ON c.circuitId = r.circuitId
            WHERE res.driverId = :driver_id
              AND r.year = :year
              AND res.positionOrder IS NOT NULL
              AND res.positionText REGEXP '^[0-9]+$'
            ORDER BY r.round ASC
        """), {"driver_id": driver_id, "year": year}).fetchall()

        # si por lo que sea sale una temporada rara con <3 carreras, reintenta con otra season del mismo driver
        if not rows or len(rows) < 3:
            years = DRIVER_SEASONS_CACHE.get(int(driver_id)) or []
            if years:
                # probar unas pocas seasons
                tries = min(8, len(years))
                for _ in range(tries):
                    year2 = random.choice(years)
                    rows = session.execute(text("""
                        SELECT
                          r.raceId,
                          r.round,
                          r.name AS race_name_en,
                          c.country AS country,
                          res.positionOrder AS finishing_position
                        FROM results res
                        JOIN races r ON r.raceId = res.raceId
                        JOIN circuits c ON c.circuitId = r.circuitId
                        WHERE res.driverId = :driver_id
                          AND r.year = :year
                          AND res.positionOrder IS NOT NULL
                          AND res.positionText REGEXP '^[0-9]+$'
                        ORDER BY r.round ASC
                    """), {"driver_id": driver_id, "year": year2}).fetchall()
                    if rows and len(rows) >= 3:
                        year = year2
                        break

            if not rows or len(rows) < 3:
                # fallback duro
                return get_driver_season_game()

        max_pos = _max_position_for_season(session, year)

        rounds = []
        for race_id, round_num, race_name_en, country, finishing_pos in rows:
            race_name_en = (race_name_en or "").strip()
            race_name_es = translate_gp_name(race_name_en)

            rounds.append({
                "raceId": int(race_id),
                "roundNumber": int(round_num),
                "country": (country or "").strip(),
                "raceNameEn": race_name_en,
                "raceNameEs": race_name_es,
                "finishingPosition": int(finishing_pos)
            })

        return {
            "driverId": int(driver_id),
            "driverName": driver_name,
            "seasonYear": int(year),
            "maxPosition": int(max_pos),
            "rounds": rounds
        }

    finally:
        session.close()

if __name__ == "__main__":
    import json
    print(json.dumps(get_driver_season_game(), ensure_ascii=False))
