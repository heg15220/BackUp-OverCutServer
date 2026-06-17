# resources/scripts/tower_autocomplete.py
import os
from sqlalchemy import create_engine, text
from fastapi.responses import JSONResponse

DB_URI = os.getenv("DB_URI", "mysql+pymysql://root:root@db:3306/f1db")
engine = create_engine(DB_URI, pool_pre_ping=True)


def autocomplete_pilot_ids(partial: str, limit: int = 10):
    """
    Devuelve sugerencias con ID:
      [
        {"driverId": 1, "driverName": "Lewis Hamilton"},
        ...
      ]
    """
    q = (partial or "").strip()
    if not q:
        return JSONResponse(content=[])

    # Normaliza espacios múltiples
    q = " ".join(q.split())

    with engine.connect() as conn:
        rows = conn.execute(text("""
            SELECT d.driverId, CONCAT(d.forename,' ',d.surname) AS fullName
            FROM drivers d
            WHERE CONCAT(d.forename,' ',d.surname) LIKE :pat
            ORDER BY d.surname ASC, d.forename ASC
            LIMIT :lim
        """), {"pat": f"%{q}%", "lim": int(limit)}).fetchall()

    payload = [{"driverId": int(r[0]), "driverName": str(r[1])} for r in rows]
    return JSONResponse(content=payload)
