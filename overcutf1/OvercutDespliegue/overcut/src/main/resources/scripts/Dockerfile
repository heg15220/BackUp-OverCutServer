FROM python:3.11-slim

WORKDIR /app

RUN apt-get update && apt-get install -y build-essential default-libmysqlclient-dev && rm -rf /var/lib/apt/lists/*

COPY . /app

RUN pip install --no-cache-dir fastapi "uvicorn[standard]" gunicorn "sqlalchemy<2.0" "pymysql[rsa]" cryptography

EXPOSE 8000

# ✅ 4 vCPU: 3 workers es buen equilibrio. (2 si quieres aún menos RAM)
CMD ["gunicorn","-k","uvicorn.workers.UvicornWorker","-w","3","--threads","2","-b","0.0.0.0:8000","--timeout","60","--keep-alive","75","main:app"]

