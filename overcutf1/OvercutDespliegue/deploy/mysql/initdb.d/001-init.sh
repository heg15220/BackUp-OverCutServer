#!/usr/bin/env bash
set -euo pipefail

mysql -uroot -p"root" <<SQL
-- Bases
CREATE DATABASE IF NOT EXISTS \`overcutdb\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`f1hubdb\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE DATABASE IF NOT EXISTS \`f1db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

-- Usuarios/Permisos
CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON \`overcutdb\`.* TO 'root'@'%';
GRANT SELECT ON \`f1db\`.* TO 'root'@'%';

CREATE USER IF NOT EXISTS 'root'@'%' IDENTIFIED BY 'root';
GRANT ALL PRIVILEGES ON \`f1hubdb\`.* TO 'root'@'%';
GRANT SELECT ON \`f1db\`.* TO 'root'@'%';

FLUSH PRIVILEGES;
SQL
