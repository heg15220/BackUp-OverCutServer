import json
import os
import re
from pathlib import Path
from typing import List

# Por defecto, al estar montado /app/resources/scripts en tu contenedor,
# este path existe.
SCRIPT_DIR = Path(__file__).resolve().parent
CACHE_FILE = Path(os.getenv("PILOT_CACHE_FILE", str(SCRIPT_DIR / "driver_fullnames_cache.json")))

_PILOT_NAMES: List[str] = []
_PILOT_NAMES_PLAIN: List[str] = []

def normalize(s: str) -> str:
    s = (s or "").strip().lower()
    s = re.sub(r"\s+", " ", s)
    # dejamos letras/números/acentos y espacio
    s = re.sub(r"[^a-z0-9áéíóúüñ ]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()
    return s

def load_pilot_cache() -> int:
    global _PILOT_NAMES, _PILOT_NAMES_PLAIN
    if not CACHE_FILE.exists():
        print(f"[WARN] Pilot cache JSON no encontrado: {CACHE_FILE}")
        _PILOT_NAMES = []
        _PILOT_NAMES_PLAIN = []
        return 0

    with CACHE_FILE.open("r", encoding="utf-8") as f:
        data = json.load(f)

    if not isinstance(data, list):
        raise RuntimeError(f"Pilot cache JSON inválido (no es lista): {CACHE_FILE}")

    _PILOT_NAMES = [str(x) for x in data]
    _PILOT_NAMES_PLAIN = [normalize(x) for x in _PILOT_NAMES]

    print(f"[startup] Pilot cache cargada: {len(_PILOT_NAMES)} nombres")
    return len(_PILOT_NAMES)

def autocomplete_from_cache(query: str, limit: int = 10) -> List[str]:
    q = normalize(query)
    if len(q) < 2 or not _PILOT_NAMES:
        return []

    # búsqueda "contiene" rápida en memoria (864 -> instantáneo)
    out = []
    for original, plain in zip(_PILOT_NAMES, _PILOT_NAMES_PLAIN):
        if q in plain:
            out.append(original)
            if len(out) >= limit:
                break
    return out
