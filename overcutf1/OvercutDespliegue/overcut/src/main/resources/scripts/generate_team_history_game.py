# generate_team_history_game.py
# -*- coding: utf-8 -*-

import os
import random
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DB_URL = os.getenv("DB_URI", "mysql+pymysql://root:root@db:3306/f1db")
engine = create_engine(DB_URL, pool_pre_ping=True)
Session = sessionmaker(bind=engine)

# ==========================================================
# ✅ POOLS / CACHÉS EN MEMORIA (igual filosofía que DriverSeason)
# ==========================================================
CONSTRUCTORS_WITH_HISTORY_POOL: list[int] = []
CONSTRUCTOR_SEASONS_CACHE: dict[int, list[tuple[int, int]]] = {}  # cid -> [(year, pos)]
CONSTRUCTOR_NAME_CACHE: dict[int, str] = {}
MAX_CONSTRUCTOR_POS: int = 12


def warmup_team_history_pools(min_seasons: int = 8, min_year: int = 1950):
    """
    Precarga en RAM:
    - Pool de constructores con >= min_seasons en standings de final de temporada
    - Para cada constructor, lista [(year, position)] en final de temporada
    - Nombres de constructor
    - max posición global
    Evita ORDER BY RAND() en constructorStandings.
    """
    global CONSTRUCTORS_WITH_HISTORY_POOL, CONSTRUCTOR_SEASONS_CACHE, CONSTRUCTOR_NAME_CACHE, MAX_CONSTRUCTOR_POS

    session = Session()
    try:
        # 1) max posición global (para el selector)
        MAX_CONSTRUCTOR_POS = int(
            session.execute(text("""
                SELECT MAX(cs.position)
                FROM constructorStandings cs
                WHERE cs.position IS NOT NULL
            """)).scalar() or 12
        )

        # 2) cache de nombres
        rows_names = session.execute(text("""
            SELECT constructorId, name
            FROM constructors
        """)).fetchall()
        CONSTRUCTOR_NAME_CACHE = {int(cid): (name or "").strip() for (cid, name) in rows_names}

        # 3) standings fin de temporada por constructor (una fila por year)
        #    Nota: usamos el "último round" de cada year (igual que tu query original)
        rows = session.execute(text("""
            SELECT
              cs.constructorId AS constructorId,
              r.year AS seasonYear,
              cs.position AS finishingPosition
            FROM constructorStandings cs
            JOIN races r ON r.raceId = cs.raceId
            WHERE r.year >= :min_year
              AND cs.position IS NOT NULL
              AND r.round = (
                  SELECT MAX(r2.round) FROM races r2 WHERE r2.year = r.year
              )
            ORDER BY cs.constructorId ASC, r.year ASC
        """), {"min_year": min_year}).fetchall()

        tmp: dict[int, list[tuple[int, int]]] = {}
        for cid, year, pos in rows:
            if cid is None or year is None or pos is None:
                continue
            cid = int(cid)
            y = int(year)
            p = int(pos)
            tmp.setdefault(cid, []).append((y, p))

        # 4) filtrar por min_seasons y generar pool
        CONSTRUCTOR_SEASONS_CACHE = {cid: seasons for cid, seasons in tmp.items() if len(seasons) >= min_seasons}
        CONSTRUCTORS_WITH_HISTORY_POOL = list(CONSTRUCTOR_SEASONS_CACHE.keys())
        random.shuffle(CONSTRUCTORS_WITH_HISTORY_POOL)

        print(
            f"[startup] TeamHistory pools cargados: "
            f"constructores>= {min_seasons} seasons = {len(CONSTRUCTORS_WITH_HISTORY_POOL)}, "
            f"maxPos={MAX_CONSTRUCTOR_POS}, "
            f"names={len(CONSTRUCTOR_NAME_CACHE)}"
        )

    finally:
        session.close()


def _pick_constructor_with_history(min_seasons: int = 8) -> int:
    if not CONSTRUCTORS_WITH_HISTORY_POOL:
        warmup_team_history_pools(min_seasons=min_seasons)
    if not CONSTRUCTORS_WITH_HISTORY_POOL:
        raise RuntimeError("No hay constructores con historial suficiente (pool vacío).")
    return random.choice(CONSTRUCTORS_WITH_HISTORY_POOL)


def get_team_history_game(lang="es", min_seasons: int = 8):
    """
    Genera un juego usando caches.
    lang lo dejamos por consistencia aunque aquí no se usa (por ahora).
    """
    # aseguramos warmup
    if not CONSTRUCTORS_WITH_HISTORY_POOL or not CONSTRUCTOR_SEASONS_CACHE:
        warmup_team_history_pools(min_seasons=min_seasons)

    constructor_id = _pick_constructor_with_history(min_seasons=min_seasons)
    name = CONSTRUCTOR_NAME_CACHE.get(int(constructor_id), "").strip()

    seasons = CONSTRUCTOR_SEASONS_CACHE.get(int(constructor_id)) or []
    if len(seasons) < min_seasons:
        # muy raro si el cache está bien, pero por seguridad:
        return get_team_history_game(lang, min_seasons=min_seasons)

    # ✅ recortamos a un bloque continuo aleatorio (como ya hacías)
    window = random.randint(min_seasons, min(14, len(seasons)))
    start = random.randint(0, len(seasons) - window)
    block = seasons[start:start + window]

    return {
        "constructorId": int(constructor_id),
        "constructorName": name,
        "maxPosition": int(MAX_CONSTRUCTOR_POS or 12),
        "seasons": [{"seasonYear": y, "finishingPosition": p} for (y, p) in block]
    }


if __name__ == "__main__":
    import json
    print(json.dumps(get_team_history_game(), ensure_ascii=False))
