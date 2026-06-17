import sys
import re
import unicodedata
import html
import os
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DB_CONNECTION = os.getenv("DB_URI", "mysql+pymysql://root:root@db:3306/f1db")

engine = create_engine(DB_CONNECTION, pool_size=25, max_overflow=10, future=True)
Session = sessionmaker(bind=engine)

# ========== NORMALIZACIÓN ÚNICA ==========

def normalize(text: str) -> str:
    """
    Normaliza para validar:
    - Desescapa HTML (&amp; -> &)
    - Quita tildes (NFKD)
    - Elimina todo salvo [A-Za-z0-9]
    - a minúsculas
    """
    if not text:
        return ""
    text = html.unescape(text)
    text = unicodedata.normalize("NFKD", text)
    text = "".join(ch for ch in text if not unicodedata.combining(ch))
    return re.sub(r"[^A-Za-z0-9]", "", text).lower()

def clean_nat(n):
    return re.sub(r'[^a-zA-Z]', '', (n or "").strip().lower())

# ========== VALIDADORES ==========

def validate_driver(connection, word, clue):
    try:
        normalized_word = normalize(word)
        rows = connection.execute(text("SELECT driverId, forename, surname, nationality FROM drivers")).mappings().all()

        for row in rows:
            full_name = f"{row['forename']} {row['surname']}"
            if normalize(full_name) != normalized_word:
                continue

            # Validar nacionalidad si aparece en la pista
            if "nacionalidad" in clue.lower() or "nationality" in clue.lower():
                match = re.search(r"(nacionalidad|nationality):\s*([a-zA-Z]+)", clue, re.IGNORECASE)
                if match:
                    expected_nat = clean_nat(match.group(2))
                    actual_nat = clean_nat(row["nationality"])
                    if actual_nat != expected_nat:
                        continue

            # Validar debut si aparece en la pista
            if "debutó en" in clue.lower() or "debut in" in clue.lower():
                match = re.search(r"(debutó en|debut in)\s*(\d{4})", clue, re.IGNORECASE)
                if match:
                    expected_year = int(match.group(2))
                    debut_row = connection.execute(text("""
                        SELECT MIN(r.year) AS debut_year
                        FROM results res
                        JOIN races r ON res.raceId = r.raceId
                        WHERE res.driverId = :driverId
                    """), {"driverId": row["driverId"]}).mappings().fetchone()
                    if not debut_row or debut_row["debut_year"] != expected_year:
                        continue

            return True  # ✅ match + filtros OK

        return False
    except Exception as e:
        print(f"[ERROR DRIVER] {e}", file=sys.stderr)
        return False


def validate_constructor(connection, word, clue):
    try:
        normalized_word = normalize(word)
        rows = connection.execute(text("""
            SELECT constructorId, name, nationality FROM constructors
        """)).mappings().all()

        for row in rows:
            c_name_norm = normalize(row["name"])
            if c_name_norm != normalized_word:
                continue

            # Validar nacionalidad si se menciona
            if "nacionalidad" in clue.lower() or "nationality" in clue.lower():
                match = re.search(r"(nacionalidad|nationality):\s*([a-zA-Z]+)", clue, re.IGNORECASE)
                if match:
                    expected_nat = clean_nat(match.group(2))
                    actual_nat = clean_nat(row["nationality"])
                    if actual_nat != expected_nat:
                        continue

            # Validar debut si se menciona
            if "debutó en" in clue.lower() or "debuted in" in clue.lower():
                match = re.search(r"(debutó en|debuted in)\s*(\d{4})", clue, re.IGNORECASE)
                if match:
                    expected_year = int(match.group(2))
                    debut_row = connection.execute(text("""
                        SELECT MIN(r.year) AS debut
                        FROM constructorResults cr
                        JOIN races r ON cr.raceId = r.raceId
                        WHERE cr.constructorId = :constructorId
                    """), {"constructorId": row["constructorId"]}).mappings().fetchone()
                    if not debut_row or debut_row["debut"] != expected_year:
                        continue

            return True  # ✅ match + filtros OK

        return False
    except Exception as e:
        print(f"[ERROR CONSTRUCTOR] {e}", file=sys.stderr)
        return False


def validate_circuit(connection, word, clue):
    try:
        normalized_word = normalize(word)
        rows = connection.execute(text("""
            SELECT circuitId, circuitRef, name, location, country
            FROM circuits
        """)).mappings().all()

        for row in rows:
            candidates = [row["circuitRef"], row["name"], row["location"]]
            if any(normalize(x) == normalized_word for x in candidates if x):
                # Validar país si se menciona en la pista
                if re.search(r"(pa[ií]s|country):", clue, re.IGNORECASE):
                    m = re.search(r"(pa[ií]s|country):\s*([a-zA-Z]+)", clue, re.IGNORECASE)
                    if m:
                        expected_country = clean_nat(m.group(2))
                        actual_country = clean_nat(row["country"])
                        if actual_country != expected_country:
                            continue
                return True

        return False
    except Exception as e:
        print(f"[ERROR CIRCUIT] {e}", file=sys.stderr)
        return False


def validate_race(connection, word, clue):
    try:
        # Para carreras específicas: si tuvieras palabras de tipo 'race', normaliza y compara por name
        normalized_word = normalize(word)
        rows = connection.execute(text("SELECT name FROM races")).mappings().all()
        for r in rows:
            if normalize(r["name"]) == normalized_word:
                return True
        return False
    except Exception as e:
        print(f"[ERROR RACE] {e}", file=sys.stderr)
        return False

# ========== ORQUESTADOR ==========

def validate_word_and_clue(word: str, clue: str, lang: str) -> bool:
    with engine.connect() as conn:
        if validate_driver(conn, word, clue):
            return True
        if validate_constructor(conn, word, clue):
            return True
        if validate_circuit(conn, word, clue):
            return True
        if validate_race(conn, word, clue):
            return True
        return False

if __name__ == "__main__":
    if len(sys.argv) != 4:
        print("[ERROR] Invalid arguments", file=sys.stderr)
        sys.exit(1)
    word, clue, lang = sys.argv[1], sys.argv[2], sys.argv[3]
    result = validate_word_and_clue(word, clue, lang)
    print("true" if result else "false")
