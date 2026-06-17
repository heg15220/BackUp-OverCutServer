#!/usr/bin/env bash
set -euo pipefail

echo "[initdb] Esperando a que MySQL esté disponible..."
until mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; do
  sleep 1
done

echo "[initdb] Creando bases de datos..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE DATABASE IF NOT EXISTS \`${MYSQL_F1DB_NAME}\`   CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_OVERCUT_DB}\`  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`${MYSQL_F1HUB_DB}\`    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
SQL

echo "[initdb] Creando usuarios y permisos..."
mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
CREATE USER IF NOT EXISTS '${MYSQL_FASTAPI_USER}'@'%' IDENTIFIED BY '${MYSQL_FASTAPI_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_OVERCUT_USER}'@'%' IDENTIFIED BY '${MYSQL_OVERCUT_PASSWORD}';
CREATE USER IF NOT EXISTS '${MYSQL_F1HUB_USER}'@'%' IDENTIFIED BY '${MYSQL_F1HUB_PASSWORD}';

-- FastAPI (solo lectura a f1db)
GRANT SELECT ON \`${MYSQL_F1DB_NAME}\`.* TO '${MYSQL_FASTAPI_USER}'@'%';

-- OverCut (RW a su BD; lectura opcional a f1db si algún endpoint lo requiere)
GRANT ALL PRIVILEGES ON \`${MYSQL_OVERCUT_DB}\`.* TO '${MYSQL_OVERCUT_USER}'@'%';
GRANT SELECT ON \`${MYSQL_F1DB_NAME}\`.* TO '${MYSQL_OVERCUT_USER}'@'%';

-- f1Hub (RW a su BD; lectura a f1db para estadísticas)
GRANT ALL PRIVILEGES ON \`${MYSQL_F1HUB_DB}\`.* TO '${MYSQL_F1HUB_USER}'@'%';
GRANT SELECT ON \`${MYSQL_F1DB_NAME}\`.* TO '${MYSQL_F1HUB_USER}'@'%';

FLUSH PRIVILEGES;
SQL

echo "[initdb] Listo."
