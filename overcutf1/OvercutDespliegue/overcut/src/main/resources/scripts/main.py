# main.py
# ✅ Versión “server-safe” con:
#   1) Endpoint dedicado de sugerencias para TeamNationality: GET /autocomplete-team-nationality
#   2) Rutas de caché robustas (sin duplicar /resources/scripts/...)
#   3) Mantiene tu lógica actual + warmups/precaches del servidor
#   4) ✅ FIX CRÍTICO Tower: POST /validate-tower y /tower-hint-value aceptan body opcional + validación (evita "Field required")

import sys
sys.argv = [sys.argv[0]]

from fastapi import FastAPI, Query, Body
from fastapi.responses import JSONResponse
import uvicorn
import os
from typing import Optional, Any, Dict
import pickle
import random
from pathlib import Path
from contextlib import asynccontextmanager
import io
import json
import gzip

# =========================
# Imports de tus scripts
# =========================
from generate_drivers_connections import generate_game as generate_drivers_game
from generate_drivers_connections import precache_static_categories
from generate_drivers_connections import precache_dynamic_lists
from generate_crossword import main as generate_crossword_main
from validate_crossword_word import validate_word_and_clue
from select_driver_teams import generate_career_path_game
from autocomplete_grid_pilot import autocomplete_pilots
from select_driver_teammates import generate_drivers_link_game
from generate_f1_impostor import generate_f1_impostor_game
from select_wordle_driver import generate_f1_wordle_game
from get_drivers_for_season import get_drivers_for_season
from validate_grid_game import pilot_exists_for_season
from get_pilot_nationality import get_nationality

from generate_top10_game import get_random_race_and_top10
from validate_top10_pilot import validate_pilot_in_top10

from generate_order_drivers import (
    generate_order_game,
    load_teams_with_min_wins,
    load_teams_with_enough_races_or_wins,
    load_valid_circuits,
    load_valid_nationalities,
    engine,
    ensure_order_caches_ready,
)

from select_random_driver import get_random_driver
from validate_guess_driver_question import main as validate_question_main
from get_recommendations import get_recommendations
from recommend_pilots import recommend_pilots
from generate_rondo import generar_rosco
from validate_rondo_answer import validate_answer
from select_team_and_podium_drivers import generate_team_guess_data
from autocomplete_teams import autocomplete_teams
from select_teams_pilot import get_team_pairs_with_common_drivers
from validate_two_teams_driver import validate_driver
from generate_wordsearch import generate_wordsearch_grid
from validate_pilot import validate_pilot
from autocomplete_pilot import buscar_pilotos

from generate_questions import generar_preguntas_desde_main
from regulation_questions import generar_preguntas_reglamento_desde_main
from strategy_questions import generar_preguntas_estrategia_desde_main
from physics_questions import generar_preguntas_fisica_desde_main
from team_radio_questions import generar_preguntas_teamradios
from validate_category_answer import validate_category_answer

from generic_stats_service import load_generic_stats_cache, generar_preguntas_genericstats_desde_main
from validate_guess_driver_question import NATIONALITY_TRANSLATIONS_EN, NATIONALITY_TRANSLATIONS

from pilot_cache import load_pilot_cache, autocomplete_from_cache

from generate_top10quali_game import get_random_race_and_top10quali, warmup_top10quali_race_pool
from validate_top10quali_pilot import validate_pilot_in_top10quali
from generate_driver_season_game import get_driver_season_game, warmup_driver_season_pools

from tower_game import (
    precache_dynamic_lists as tower_precache_dynamic_lists,
    generate_tower,
    generate_tower_fixed,
    validate_driver as validate_tower_driver,
    get_tower_themes,
    resolve_tower_hint,
)
from tower_autocomplete import autocomplete_pilot_ids as tower_autocomplete_pilot_ids

from select_anagram_driver import generate_f1_anagrams_game  # (si lo usas en algún endpoint)
from sqlalchemy import text

from generate_bingo import generate_bingo_game, load_driver_pool
from generate_timeline_game import generate_timeline_game, load_timeline_pools
from generate_who_is_who import generate_who_is_who_game, load_whoiswho_pool
from generate_memory_game import generate_memory_game, warmup_memory_caches
from generate_team_history_game import get_team_history_game, warmup_team_history_pools
from generate_higher_lower import generate_higher_lower_game, warmup_higher_lower_caches

from thirty_seconds_game import generate_30_seconds_theme, validate_30_seconds, warmup_30s_pools
from driver_stats_game import warmup_driver_stats_pool, generate_driver_stats_game, validate_driver_stats
from abbreviations_game import generate_abbreviations_game

from team_nationality_game import generate_team_nationality, _valid_driver_for_pair


# =========================
# Paths / Cache dirs (FIX)
# =========================
HERE = Path(__file__).resolve().parent  # .../resources/scripts
SCRIPTS_ROOT = HERE

RES_SCRIPTS_A = SCRIPTS_ROOT / "resources" / "scripts"
RES_SCRIPTS_B = SCRIPTS_ROOT  # fallback: mismos scripts
RESOURCES_SCRIPTS_DIR = RES_SCRIPTS_A if RES_SCRIPTS_A.exists() else RES_SCRIPTS_B

CACHE_DIR = Path(os.getenv("CACHE_DIR", str(SCRIPTS_ROOT))).resolve()
CACHE_DATA_DIR = Path(os.getenv("CACHE_DATA_DIR", str(CACHE_DIR / "cache"))).resolve()

# =========================
# Bingo cache (preload)
# =========================
BINGO_CACHE = {"es": [], "en": []}
BINGO_CACHE_META = {"es": None, "en": None}

def load_bingo_cache_files():
    """
    Carga:
      - CACHE_DATA_DIR/bingo_cache_es.json(.gz)
      - CACHE_DATA_DIR/bingo_cache_en.json(.gz)
    """
    global BINGO_CACHE, BINGO_CACHE_META

    for lang in ["es", "en"]:
        base = CACHE_DATA_DIR / f"bingo_cache_{lang}.json"
        gz = Path(str(base) + ".gz")
        path = gz if gz.exists() else base

        if not path.exists():
            print(f"[WARN] No se encontró bingo cache para {lang}: {base}(.gz)")
            continue

        try:
            if path.suffix == ".gz":
                raw = gzip.decompress(path.read_bytes()).decode("utf-8")
                payload = json.loads(raw)
            else:
                payload = json.loads(path.read_text(encoding="utf-8"))

            games = payload.get("games", [])
            BINGO_CACHE[lang] = games
            BINGO_CACHE_META[lang] = {
                "count": payload.get("count", len(games)),
                "generatedAt": payload.get("generatedAt"),
                "compact": payload.get("compact", False),
                "version": payload.get("version"),
                "path": str(path),
            }

            print(
                f"[startup] Bingo cache {lang.upper()} cargado: "
                f"{len(games)} games (compact={BINGO_CACHE_META[lang]['compact']})"
            )
        except Exception as e:
            print(f"[ERROR] Cargando bingo cache {lang}: {e}")

def compact_bingo_game(game: dict) -> dict:
    """
    Asegura salida compacta:
    - validPilots => validPilotIds (solo ids)
    """
    cells = game.get("cells", []) or []
    compact_cells = []

    for c in cells:
        if "validPilotIds" in c and isinstance(c.get("validPilotIds"), list):
            compact_cells.append({
                "code": c.get("code"),
                "description": c.get("description"),
                "image": c.get("image"),
                "meta": c.get("meta"),
                "validPilotIds": c.get("validPilotIds"),
            })
            continue

        pilots = c.get("validPilots", []) or []
        compact_cells.append({
            "code": c.get("code"),
            "description": c.get("description"),
            "image": c.get("image"),
            "meta": c.get("meta"),
            "validPilotIds": [p.get("driverId") for p in pilots if p.get("driverId") is not None],
        })

    return {
        "cells": compact_cells,
        "driversQueue": game.get("driversQueue", []) or [],
    }


# =========================
# Tikitaka criteria cache
# =========================
CACHED_RANGES = [
    (2000, None),
    (1980, None),
    (1980, 1999),
]

CONFIGS_CACHE: dict[tuple[int, Optional[int], str], list] = {}

def cache_file_for(since_year: int, end_year: Optional[int], mode: str):
    suffix = f"{since_year}_{end_year if end_year is not None else 'plus'}"
    if mode == "teamsOnly":
        return CACHE_DATA_DIR / f"configs_cache_{suffix}_teamsOnly.pkl"
    return CACHE_DATA_DIR / f"configs_cache_{suffix}.pkl"

def load_criteria_cache():
    for since, end in CACHED_RANGES:
        for mode in ("normal", "teamsOnly"):
            path = cache_file_for(since, end, mode)
            if not path.exists():
                print(f"[WARN] Falta caché modo={mode} para rango {since}-{end}: {path}")
                continue
            CONFIGS_CACHE[(since, end, mode)] = pickle.loads(path.read_bytes())
    print(f"[startup] Caché de criterios TikiTaka cargado: {list(CONFIGS_CACHE.keys())}")


# =========================
# Category letter cache
# =========================
CATEGORY_CACHE: dict[str, dict[str, dict[str, bool]]] = {"es": {}, "en": {}}

def load_category_letter_cache():
    for lang in ["es", "en"]:
        file = RESOURCES_SCRIPTS_DIR / f"category_letter_cache{'_en' if lang == 'en' else ''}.json"
        if not file.exists():
            print(f"[WARN] No se encontró el archivo de caché de letras: {file}")
            continue
        try:
            with file.open(encoding="utf-8") as f:
                CATEGORY_CACHE[lang] = json.load(f)
            print(f"[startup] Caché de letras cargada para {lang.upper()}")
        except Exception as e:
            print(f"[ERROR] Cargando caché {lang}: {e}")


# =========================
# Order caches
# =========================
ORDER_TEAM_CACHE_MIN_WINS = []
ORDER_TEAM_CACHE_LONG_CAREER = []
ORDER_CIRCUIT_CACHE = []
ORDER_NATIONALITY_CACHE = []

def precache_order_teams():
    global ORDER_TEAM_CACHE_MIN_WINS, ORDER_TEAM_CACHE_LONG_CAREER
    with engine.connect() as conn:
        ORDER_TEAM_CACHE_MIN_WINS = load_teams_with_min_wins(conn)
        ORDER_TEAM_CACHE_LONG_CAREER = load_teams_with_enough_races_or_wins(conn)
    print(f"[startup] Teams with wins >=5: {len(ORDER_TEAM_CACHE_MIN_WINS)}")
    print(f"[startup] Teams with 100 races or >=5 wins: {len(ORDER_TEAM_CACHE_LONG_CAREER)}")

def precache_order_circuits():
    global ORDER_CIRCUIT_CACHE
    with engine.connect() as conn:
        ORDER_CIRCUIT_CACHE = load_valid_circuits(conn)
    print(f"[startup] Circuits with >=5 distinct drivers: {len(ORDER_CIRCUIT_CACHE)}")

def precache_order_nationalities():
    global ORDER_NATIONALITY_CACHE
    with engine.connect() as conn:
        ORDER_NATIONALITY_CACHE = load_valid_nationalities(conn)
    print(f"[startup] Nationalities with >=5 winning drivers: {len(ORDER_NATIONALITY_CACHE)}")


# =========================
# Anagrams pool (si lo usas)
# =========================
ANAGRAM_POOL = []

def load_anagram_pool():
    global ANAGRAM_POOL
    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT d.driverId, d.surname
            FROM drivers d
            JOIN results r ON d.driverId = r.driverId
            JOIN races ra ON r.raceId = ra.raceId
            WHERE ra.year >= 1980
              AND d.surname IS NOT NULL
              AND LENGTH(d.surname) BETWEEN 4 AND 18
            GROUP BY d.driverId, d.surname
            HAVING COUNT(*) >= 5
        """)).fetchall()
    ANAGRAM_POOL = [{"driverId": r[0], "surname": r[1]} for r in rows]
    print("[startup] Anagrams pool:", len(ANAGRAM_POOL))


# =========================
# FastAPI lifespan
# =========================
@asynccontextmanager
async def lifespan(app: FastAPI):
    load_criteria_cache()
    load_category_letter_cache()

    precache_static_categories()
    precache_dynamic_lists()

    precache_order_teams()
    precache_order_circuits()
    precache_order_nationalities()

    load_generic_stats_cache("generic_stats_data.json")
    load_pilot_cache()

    tower_precache_dynamic_lists()

    load_anagram_pool()
    load_timeline_pools()
    load_driver_pool()
    load_whoiswho_pool()

    warmup_higher_lower_caches(force=True)
    warmup_memory_caches(force=True)

    load_bingo_cache_files()

    warmup_driver_stats_pool(min_races=20)
    warmup_top10quali_race_pool(min_year=1985)
    warmup_driver_season_pools(min_year=1950)
    warmup_team_history_pools(min_seasons=8, min_year=1950)
    warmup_30s_pools()

    yield


app = FastAPI(lifespan=lifespan)


# =========================
# Tikitaka criteria
# =========================
@app.get("/generate-tikitaka-criteria")
def generate_tikitaka_criteria(
    sinceYear: int = Query(2000),
    endYear: Optional[int] = Query(None),
    teamsOnly: bool = Query(False),
):
    mode = "teamsOnly" if teamsOnly else "normal"
    key = (sinceYear, endYear, mode)
    configs = CONFIGS_CACHE.get(key)

    if not configs:
        return JSONResponse(
            content={"error": f"No hay configuraciones precargadas para rango {sinceYear}-{endYear} (mode={mode})"},
            status_code=400,
        )
    return JSONResponse(content=random.choice(configs))

from fastapi import Query
from fastapi.responses import JSONResponse
import random

@app.get("/generate-f1-anagrams")
def generate_f1_anagrams(n: int = Query(6, ge=1, le=12)):
    try:
        # Usa el pool precargado si existe
        if "ANAGRAM_POOL" in globals() and ANAGRAM_POOL and len(ANAGRAM_POOL) >= n:
            drivers = random.sample(ANAGRAM_POOL, n)
            return JSONResponse(content={"drivers": drivers})

        # Fallback a query directa si por lo que sea no hay pool
        result = generate_f1_anagrams_game(n)
        return JSONResponse(content=result)

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)



# =========================
# OverCutGames: Drivers Connections
# =========================
@app.get("/generate")
def generate_drivers_connections(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = generate_drivers_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Crossword
# =========================
@app.get("/generate-crossword")
def generate_crossword(rows: int = 10, cols: int = 10, lang: str = Query("es", enum=["es", "en"])):
    try:
        sys.argv = ["generate_crossword.py", str(rows), str(cols), lang]
        sys_stdout = io.StringIO()
        sys.stdout = sys_stdout

        generate_crossword_main()

        sys.stdout = sys.__stdout__
        output = sys_stdout.getvalue()
        return JSONResponse(content=json.loads(output))
    except Exception as e:
        sys.stdout = sys.__stdout__
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-crossword-word")
def validate_crossword_word(word: str, clue: str, lang: str = Query("es", enum=["es", "en"])):
    try:
        result = validate_word_and_clue(word, clue, lang)
        return result
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Career Path
# =========================
@app.get("/generate-career-path")
def generate_career_path():
    try:
        result = generate_career_path_game()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/autocomplete-career-pilot")
def autocomplete_career_pilot(partial: str):
    try:
        cached = autocomplete_from_cache(partial, limit=10)
        if cached:
            return JSONResponse(content=cached)
        suggestions = autocomplete_pilots(partial)
        return JSONResponse(content=suggestions)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Drivers Link
# =========================
@app.get("/generate-drivers-link")
def generate_drivers_link():
    try:
        result = generate_drivers_link_game()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Impostor / Wordle
# =========================
@app.get("/generate-f1-impostor")
def generate_f1_impostor(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = generate_f1_impostor_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-f1-wordle")
def generate_f1_wordle():
    try:
        result = generate_f1_wordle_game()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Grid game
# =========================
@app.get("/get-drivers-for-season")
def get_drivers(season: int):
    try:
        result = get_drivers_for_season(season)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-grid-pilot")
def validate_grid_pilot(pilot: str, season: int):
    try:
        valid = pilot_exists_for_season(pilot, season)
        return JSONResponse(content={"valid": valid})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/get-pilot-nationality")
def get_pilot_nationality(pilot: str, season: int):
    try:
        nationality = get_nationality(pilot, season)
        return JSONResponse(content={"nationality": nationality})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/autocomplete-grid-pilot")
def autocomplete_grid_pilot(partial: str):
    try:
        cached = autocomplete_from_cache(partial, limit=10)
        if cached:
            return JSONResponse(content=cached)
        result = autocomplete_pilots(partial)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Top10
# =========================
@app.get("/generate-top10-game")
def generate_top10_game(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = get_random_race_and_top10(lang=lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-top10-pilot")
def validate_top10_pilot(pilot: str, raceId: int):
    try:
        result = validate_pilot_in_top10(pilot, raceId)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Order game
# =========================
@app.get("/generate-order-game")
def generate_order_game_endpoint(lang: str = Query("es", enum=["es", "en"])):
    try:
        ensure_order_caches_ready()
        result = generate_order_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Guess Driver
# =========================
@app.get("/generate-guess-driver")
def generate_guess_driver():
    try:
        result = get_random_driver()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-guess-question")
def validate_guess_question(
    driverId: int,
    category: str,
    value: str = None,
    lang: str = Query("es", enum=["es", "en"]),
):
    try:
        os.environ["LANG"] = lang
        sys.argv = ["validate_guess_driver_question.py", str(driverId), category]
        if value:
            sys.argv.append(value)

        stdout_backup = sys.stdout
        sys.stdout = io.StringIO()

        validate_question_main()

        sys.stdout.seek(0)
        output = sys.stdout.read()
        sys.stdout = stdout_backup

        return JSONResponse(content=json.loads(output))
    except Exception as e:
        sys.stdout = sys.__stdout__
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/recommend-guess-values")
def recommend_guess_values(category: str, lang: str = Query("es", enum=["es", "en"])):
    os.environ["LANG"] = lang
    result = get_recommendations(category)

    if category == "nationality":
        if lang == "en":
            result = [NATIONALITY_TRANSLATIONS_EN.get(n, n) for n in result]
        else:
            result = [NATIONALITY_TRANSLATIONS.get(n, n) for n in result]

    return JSONResponse(content=result)


# =========================
# Autocomplete (global)
# =========================
@app.get("/autocomplete-pilot")
def autocomplete_pilot_endpoint(partial: str):
    try:
        cached = autocomplete_from_cache(partial, limit=10)
        if cached:
            return JSONResponse(content=cached)

        result = recommend_pilots(partial)
        if result:
            return JSONResponse(content=result)

        results = buscar_pilotos(partial)
        return JSONResponse(content=results)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Rondo
# =========================
@app.get("/generate-rondo")
def generate_rondo(lang: str = Query("es", enum=["es", "en"])):
    try:
        rosco = generar_rosco(lang)
        return JSONResponse(content=rosco)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-rondo-answer")
def validate_rondo_answer(letter: str, question: str, answer: str):
    try:
        valid = validate_answer(letter, question, answer)
        return {"valid": valid}
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Team Guess / Teams autocomplete
# =========================
@app.get("/generate-team-guess")
def generate_team_guess():
    try:
        result = generate_team_guess_data()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/autocomplete-team")
def autocomplete_team(partial: str):
    try:
        result = autocomplete_teams(partial)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-two-teams-one-driver")
def generate_two_teams_one_driver():
    try:
        result = get_team_pairs_with_common_drivers()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-two-teams-driver")
def validate_two_teams_driver_endpoint(driver: str, teamA: str, teamB: str):
    try:
        valid = validate_driver(driver, teamA, teamB)
        return JSONResponse(content={"valid": valid})
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Wordsearch
# =========================
@app.get("/generate-wordsearch")
def generate_wordsearch():
    try:
        result = generate_wordsearch_grid()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Tikitaka validate & autocomplete
# =========================
@app.get("/validate-tikitaka-pilot")
def validate_tikitaka_pilot(
    row: str = Query(...),
    col: str = Query(...),
    piloto: str = Query(...),
    sinceYear: Optional[int] = Query(None),
    endYear: Optional[int] = Query(None),
):
    try:
        result = validate_pilot(
            row_criteria_code=row,
            column_criteria_code=col,
            piloto=piloto,
            since_year=sinceYear,
            end_year=endYear,
        )
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(status_code=500, content={"is_valid": False, "reason": str(e)})

@app.get("/autocomplete-pilot-tictactoe")
def autocomplete_pilot_tictactoe(partial: str):
    try:
        cached = autocomplete_from_cache(partial, limit=10)
        if cached:
            return JSONResponse(content=cached)
        results = buscar_pilotos(partial)
        return JSONResponse(content=results)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Quiz endpoints
# =========================
@app.get("/generate-quiz-questions")
def generate_quiz_questions(
    lang: str = Query("es", enum=["es", "en"]),
    category: Optional[str] = Query(None),
):
    try:
        questions = generar_preguntas_desde_main(lang=lang, categoria=category)
        return JSONResponse(content=questions)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-quiz-regulation")
def generate_quiz_regulation(lang: str = Query("es"), category: Optional[str] = Query(None)):
    try:
        preguntas = generar_preguntas_reglamento_desde_main(lang=lang, category=category)
        return JSONResponse(content=preguntas)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-quiz-strategy")
def generate_quiz_strategy(lang: str = Query("es"), category: Optional[str] = Query(None)):
    try:
        preguntas = generar_preguntas_estrategia_desde_main(lang=lang, category=category)
        return JSONResponse(content=preguntas)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-quiz-physics")
def generate_quiz_physics(lang: str = Query("es"), category: Optional[str] = Query(None)):
    try:
        preguntas = generar_preguntas_fisica_desde_main(lang=lang, category=category)
        return JSONResponse(content=preguntas)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-quiz-teamradios")
def generate_quiz_teamradios(lang: str = Query("es")):
    try:
        preguntas = generar_preguntas_teamradios(lang=lang)
        return JSONResponse(content=preguntas)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-category")
def validate_category_endpoint(
    category: str = Query(...),
    answer: str = Query(...),
    letter: str = Query(...),
    lang: str = Query("es", enum=["es", "en"]),
):
    try:
        result = validate_category_answer(category, answer, letter, lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"valid": False, "error": str(e)}, status_code=500)

@app.get("/category-letter-cache")
def get_category_letter_cache(lang: str = Query("es", enum=["es", "en"])):
    return JSONResponse(content=CATEGORY_CACHE.get(lang, {}))

@app.get("/generate-quiz-genericstats")
def generate_quiz_genericstats(lang: str = Query("es", enum=["es", "en"])):
    preguntas = generar_preguntas_genericstats_desde_main(lang=lang)
    return JSONResponse(content=preguntas)


# =========================
# Top10Quali / DriverSeason
# =========================
@app.get("/generate-top10quali-game")
def generate_top10quali_game(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = get_random_race_and_top10quali(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/validate-top10quali-pilot")
def validate_top10quali_pilot(pilot: str, raceId: int):
    try:
        result = validate_pilot_in_top10quali(pilot, raceId)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-driver-season-game")
def generate_driver_season_game(lang: str = Query("es", enum=["es", "en"])):
    try:
        os.environ["LANG"] = lang
        result = get_driver_season_game()
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Tower (✅ FIX "missing body")
# =========================
@app.get("/tower-themes")
def tower_themes_endpoint():
    try:
        return JSONResponse(content=get_tower_themes())
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-tower")
def generate_tower_endpoint(
    themeType: Optional[str] = Query(None),
    themeKey: Optional[str] = Query(None),
):
    try:
        if not themeType:
            return JSONResponse(content=generate_tower())
        return JSONResponse(content=generate_tower_fixed(themeType, themeKey))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/validate-tower")
def validate_tower_endpoint(payload: Optional[Dict[str, Any]] = Body(None)):
    """
    ✅ FIX CRÍTICO:
    - Acepta body opcional para no disparar "Field required"
    - Devuelve 400 claro si falta payload o campos clave
    - Devuelve JSONResponse siempre
    """
    try:
        if payload is None:
            return JSONResponse(status_code=400, content={"valid": False, "error": "Missing JSON body"})

        theme_type = payload.get("themeType")
        theme_key = payload.get("themeKey")
        driver_id = payload.get("driverId")
        driver_name = payload.get("driverName")

        if not theme_type:
            return JSONResponse(status_code=400, content={"valid": False, "error": "Payload inválido: themeType requerido"})

        if (driver_id is None) and (not driver_name or not str(driver_name).strip()):
            return JSONResponse(
                status_code=400,
                content={"valid": False, "error": "Payload inválido: driverId o driverName requerido"},
            )

        result = validate_tower_driver(theme_type, theme_key, driver_id, driver_name)
        return JSONResponse(content=result)

    except Exception as e:
        return JSONResponse(status_code=500, content={"valid": False, "error": str(e)})

@app.post("/tower-hint-value")
def tower_hint_value_endpoint(payload: Optional[Dict[str, Any]] = Body(None)):
    """
    ✅ FIX: body opcional + validación para evitar "Field required"
    """
    try:
        if payload is None:
            return JSONResponse(status_code=400, content={"error": "Missing JSON body"})

        themeType = payload.get("themeType")
        themeKey = payload.get("themeKey")
        lang = payload.get("lang") or "es"

        if not themeType:
            return JSONResponse(status_code=400, content={"error": "Payload inválido: themeType requerido"})

        value = resolve_tower_hint(themeType, themeKey, lang=lang)
        return JSONResponse(content={"hintValue": value})

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

from fastapi.responses import JSONResponse, Response

@app.get("/autocomplete-pilot-ids")
def autocomplete_pilot_ids_endpoint(partial: str, limit: int = 10):
    try:
        res = tower_autocomplete_pilot_ids(partial, limit=limit)

        # Si la función ya devuelve un Response (JSONResponse), lo retornamos tal cual
        if isinstance(res, Response):
            return res

        # Si devuelve lista/dict, lo envolvemos
        return JSONResponse(content=res)

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# =========================
# Bingo / Timeline / WhoIsWho / Memory / TeamHistory / HigherLower
# =========================
@app.get("/generate-bingo")
def generate_bingo(lang: str = Query("es", enum=["es", "en"])):
    try:
        games = BINGO_CACHE.get(lang) or []
        if games:
            g = random.choice(games)
            return JSONResponse(content=compact_bingo_game(g))

        g = generate_bingo_game(lang)
        return JSONResponse(content=compact_bingo_game(g))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-timeline")
def generate_timeline(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = generate_timeline_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-who-is-who")
def generate_who_is_who(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = generate_who_is_who_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-memory-game")
def generate_memory(
    lang: str = Query("es", enum=["es", "en"]),
    rows: int = 4,
    cols: int = 4,
    mode: str = "classic",
):
    try:
        result = generate_memory_game(lang=lang, rows=rows, cols=cols, mode=mode)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-team-history-game")
def generate_team_history_game_endpoint(lang: str = Query("es", enum=["es", "en"])):
    try:
        os.environ["LANG"] = lang
        result = get_team_history_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-higher-lower")
def generate_higher_lower(lang: str = Query("es", enum=["es", "en"])):
    try:
        result = generate_higher_lower_game(lang)
        return JSONResponse(content=result)
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# 30 seconds / Driver stats / Abbreviations
# =========================
@app.get("/generate-30-seconds")
def generate_30_seconds(lang: str = Query("es", enum=["es", "en"])):
    try:
        return JSONResponse(content=generate_30_seconds_theme(lang))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

# ✅ FIX: themeValue correcto + validación de payload
@app.post("/validate-30-seconds")
def validate_30_seconds_endpoint(payload: dict):
    try:
        themeType = payload.get("themeType")
        themeValue = payload.get("themeValue")
        answers = payload.get("answers") or []

        if not themeType or themeValue is None:
            return JSONResponse(
                status_code=400,
                content={"error": "Payload inválido: se requiere themeType y themeValue"},
            )

        return JSONResponse(content=validate_30_seconds(themeType, themeValue, answers))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-driver-stats")
def generate_driver_stats(lang: str = Query("es", enum=["es", "en"])):
    try:
        return JSONResponse(content=generate_driver_stats_game(lang))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.post("/validate-driver-stats")
def validate_driver_stats_endpoint(payload: dict):
    try:
        driver_id = int(payload.get("driverId"))
        lang = payload.get("lang") or "es"
        answers = payload.get("answers") or {}
        return JSONResponse(content=validate_driver_stats(driver_id, answers, lang=lang))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)

@app.get("/generate-abbreviations")
def generate_abbreviations(lang: str = Query("es", enum=["es", "en"])):
    try:
        return JSONResponse(content=generate_abbreviations_game(limit=20))
    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# ✅ TeamNationality (GAME + VALIDATE + SUGGESTIONS)
# =========================
@app.get("/generate-team-nationality")
def generate_team_nat(
    lang: str = Query("es"),
    excludeTeam: Optional[str] = None,
    excludeNat: Optional[str] = None,
):
    exclude = (excludeTeam, excludeNat) if excludeTeam and excludeNat else None
    return JSONResponse(content=generate_team_nationality(exclude))

@app.post("/validate-team-nationality")
def validate_team_nat(payload: dict):
    try:
        team = payload.get("teamName")
        nat = payload.get("nationality")
        driver = payload.get("driverName")
        return JSONResponse(content=_valid_driver_for_pair(team, nat, driver))
    except Exception as e:
        return JSONResponse(content={"valid": False, "error": str(e)}, status_code=500)

@app.get("/autocomplete-team-nationality")
def autocomplete_team_nationality(partial: str, limit: int = 10):
    """
    Sugerencias de piloto para el minijuego TeamNationality.
    - 1) intenta caché (pilot_cache)
    - 2) fallback a recommend_pilots
    - 3) fallback a buscar_pilotos
    """
    try:
        s = (partial or "").strip()
        if len(s) < 2:
            return JSONResponse(content=[])

        cached = autocomplete_from_cache(s, limit=limit)
        if cached:
            return JSONResponse(content=cached)

        rec = recommend_pilots(s)
        if rec:
            return JSONResponse(content=rec[:limit])

        brute = buscar_pilotos(s)
        return JSONResponse(content=(brute or [])[:limit])

    except Exception as e:
        return JSONResponse(content={"error": str(e)}, status_code=500)


# =========================
# Main
# =========================
if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000)
