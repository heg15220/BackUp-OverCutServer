import argparse
import json
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
    s = user_input.strip().lower()
    s = re.sub(r"\s+", " ", s)
    s = re.sub(r"[^a-z0-9áéíóúüñ ]+", " ", s)
    s = re.sub(r"\s+", " ", s).strip()

    s_no_space = s.replace(" ", "")
    if len(s_no_space) < n:
        return ""

    ngrams = [s_no_space[i:i + n] for i in range(len(s_no_space) - n + 1)]
    must = ngrams[:max_ngrams]
    return " ".join([f"+{g}" for g in must])


def autocomplete_pilots(partial_name: str):
    session = Session()
    try:
        partial_name = (partial_name or "").strip()
        if len(partial_name) < 2:
            return []

        q = build_ngram_boolean_query(partial_name, n=2, max_ngrams=10)
        if not q:
            return []

        query = text("""
            SELECT CONCAT(forename, ' ', surname) AS full_name,
                   MATCH(full_name_plain) AGAINST (:q IN BOOLEAN MODE) AS score
            FROM drivers
            WHERE MATCH(full_name_plain) AGAINST (:q IN BOOLEAN MODE) > 0
            ORDER BY score DESC, full_name
            LIMIT 10
        """)

        result = session.execute(query, {"q": q}).fetchall()
        return [row[0] for row in result]
    finally:
        session.close()


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--partial", required=True, help="Nombre parcial del piloto")
    args = parser.parse_args()

    print(json.dumps(autocomplete_pilots(args.partial), ensure_ascii=False))
