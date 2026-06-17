import json
import argparse
import os
import re
from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker

DB_URL = os.getenv("DB_URI", "mysql+pymysql://root:root@db:3306/f1db")

engine = create_engine(
    DB_URL,
    pool_size=25,
    max_overflow=25,
    pool_pre_ping=True,
    pool_recycle=1800,
)
Session = sessionmaker(bind=engine)


def build_ngram_boolean_query(user_input: str, n: int = 2, max_ngrams: int = 10) -> str:
    """
    Para FULLTEXT ngram:
    - Convierte "hamilton" -> "+ha +am +mi +il +lt +to +on ..."
    - Usamos los primeros max_ngrams para no ser demasiado restrictivos.
    """
    s = user_input.strip().lower()
    s = re.sub(r"\s+", " ", s)

    # Mantén letras/números + acentos + espacio
    s = re.sub(r"[^a-z0-9áéíóúüñ ]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()

    # Para "contiene" real, quitamos espacios y ngramizamos
    s_no_space = s.replace(" ", "")
    if len(s_no_space) < n:
        return ""

    ngrams = [s_no_space[i:i + n] for i in range(len(s_no_space) - n + 1)]
    must = ngrams[:max_ngrams]

    # BOOLEAN MODE: + obliga a que aparezca
    return " ".join([f"+{g}" for g in must])


def buscar_pilotos(nombre: str):
    session = Session()
    try:
        nombre = (nombre or "").strip()
        if len(nombre) < 2:
            return []

        q = build_ngram_boolean_query(nombre, n=2, max_ngrams=10)
        if not q:
            return []

        sql = text("""
            SELECT CONCAT(forename, ' ', surname) AS full_name,
                   MATCH(full_name_plain) AGAINST (:q IN BOOLEAN MODE) AS score
            FROM drivers
            WHERE MATCH(full_name_plain) AGAINST (:q IN BOOLEAN MODE) > 0
            ORDER BY score DESC, full_name
            LIMIT 10
        """)

        rows = session.execute(sql, {"q": q}).fetchall()
        return [r[0] for r in rows]

    except Exception as e:
        raise RuntimeError(f"Error en buscar_pilotos: {e}")
    finally:
        session.close()


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--name", required=True, help="Nombre parcial del piloto")
    args = parser.parse_args()

    print(json.dumps(buscar_pilotos(args.name), ensure_ascii=False))


if __name__ == "__main__":
    main()
