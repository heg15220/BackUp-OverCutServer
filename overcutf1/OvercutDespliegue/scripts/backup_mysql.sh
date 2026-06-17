#!/bin/bash
set -euo pipefail

COMPOSE_DIR="/opt/overcutf1/OvercutDespliegue/deploy"
BACKUP_DIR="/opt/backups/mysql"
CONTAINER="db"
DATE="$(date +%F_%H-%M)"

mkdir -p "$BACKUP_DIR"

# --- Leer .env sin CRLF ---
get_env() {
  local key="$1"
  local val
  val=$(grep -E "^${key}=" "$COMPOSE_DIR/.env" | head -n1 | cut -d= -f2- | tr -d '\r')
  printf "%s" "$val"
}

# Vars
MYSQL_F1DB_NAME="$(get_env MYSQL_F1DB_NAME)"
MYSQL_OVERCUT_DB="$(get_env MYSQL_OVERCUT_DB)"
MYSQL_F1HUB_DB="$(get_env MYSQL_F1HUB_DB)"

MYSQL_FASTAPI_USER="$(get_env MYSQL_FASTAPI_USER)"
MYSQL_FASTAPI_PASSWORD="$(get_env MYSQL_FASTAPI_PASSWORD)"

MYSQL_OVERCUT_USER="$(get_env MYSQL_OVERCUT_USER)"
MYSQL_OVERCUT_PASSWORD="$(get_env MYSQL_OVERCUT_PASSWORD)"

MYSQL_F1HUB_USER="$(get_env MYSQL_F1HUB_USER)"
MYSQL_F1HUB_PASSWORD="$(get_env MYSQL_F1HUB_PASSWORD)"

# Contenedor vivo
docker ps --format '{{.Names}}' | grep -qx "$CONTAINER" || { echo "ERROR: $CONTAINER no está en ejecución"; exit 1; }

# Mapa BD -> user/pass
declare -A DB_USER DB_PASS DB_MODE
# Modo: "light" para f1db (menos privilegios); "full" para el resto
DB_USER["$MYSQL_F1DB_NAME"]="$MYSQL_FASTAPI_USER"
DB_PASS["$MYSQL_F1DB_NAME"]="$MYSQL_FASTAPI_PASSWORD"
DB_MODE["$MYSQL_F1DB_NAME"]="light"

DB_USER["$MYSQL_OVERCUT_DB"]="$MYSQL_OVERCUT_USER"
DB_PASS["$MYSQL_OVERCUT_DB"]="$MYSQL_OVERCUT_PASSWORD"
DB_MODE["$MYSQL_OVERCUT_DB"]="full"

DB_USER["$MYSQL_F1HUB_DB"]="$MYSQL_F1HUB_USER"
DB_PASS["$MYSQL_F1HUB_DB"]="$MYSQL_F1HUB_PASSWORD"
DB_MODE["$MYSQL_F1HUB_DB"]="full"

# Dump cada BD; si falla una, seguimos (sin abortar todo)
for DB in "${!DB_USER[@]}"; do
  USER="${DB_USER[$DB]}"
  PASS="${DB_PASS[$DB]}"
  MODE="${DB_MODE[$DB]}"
  OUTBASE="${BACKUP_DIR}/${DB}_${DATE}"
  OUTFILE="${OUTBASE}.sql"

  echo "=== Backup '${DB}' con usuario '${USER}' (${MODE}) ==="

  if [ "$MODE" = "full" ]; then
    # Dump completo (evitamos tablespaces por ruido de permisos)
    if docker exec "$CONTAINER" \
         mysqldump -h 127.0.0.1 -u"$USER" -p"$PASS" \
           --single-transaction --routines --triggers --events \
           --no-tablespaces --column-statistics=0 --set-gtid-purged=OFF \
           "$DB" > "$OUTFILE" 2> "${OUTBASE}.log"; then
      gzip -f "$OUTFILE"
      echo "OK: ${OUTFILE}.gz"
    else
      echo "FALLO en ${DB} (full). Revisa log: ${OUTBASE}.log"
    fi
  else
    # Modo light (solo lectura): primero intento con estructura + datos, sin rutinas/eventos, sin tablespaces
    if docker exec "$CONTAINER" \
         mysqldump -h 127.0.0.1 -u"$USER" -p"$PASS" \
           --single-transaction --triggers \
           --no-tablespaces --column-statistics=0 --set-gtid-purged=OFF \
           "$DB" > "$OUTFILE" 2> "${OUTBASE}.log"; then
      gzip -f "$OUTFILE"
      echo "OK: ${OUTFILE}.gz"
    else
      echo "Aviso: permisos insuficientes para estructura completa en '${DB}'. Intentando DATA-ONLY…"
      # Fallback: solo datos (sin CREATE TABLE/VIEW); útil si faltan SHOW VIEW, etc.
      if docker exec "$CONTAINER" \
           mysqldump -h 127.0.0.1 -u"$USER" -p"$PASS" \
             --single-transaction --no-create-db --no-create-info \
             --no-tablespaces --column-statistics=0 --set-gtid-purged=OFF \
             "$DB" > "$OUTFILE" 2>> "${OUTBASE}.log"; then
        gzip -f "$OUTFILE"
        echo "OK (DATA-ONLY): ${OUTFILE}.gz"
        echo "Nota: '${DB}' se respaldó solo con datos (sin estructura)."
      else
        echo "FALLO en ${DB} (ni full-light ni data-only). Revisa log: ${OUTBASE}.log"
      fi
    fi
  fi

done

# Rotación 7 días
find "$BACKUP_DIR" -type f -name "*.sql.gz" -mtime +7 -delete

echo "✅ Backups finalizados en $BACKUP_DIR"

