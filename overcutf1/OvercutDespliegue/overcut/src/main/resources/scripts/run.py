import sys
# Evita que argparse de tus módulos vea los args de arranque (host, port, etc.)
sys.argv = ["app"]

import uvicorn
import main  # importa tu app SOLO después de limpiar argv

# Arranca Uvicorn programáticamente (1 worker)
uvicorn.run(main.app, host="0.0.0.0", port=8000)
