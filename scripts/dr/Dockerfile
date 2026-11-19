# MoveMark — scheduled off-site backup image (Railway service `movemark-backup`, cron, built from the repo root:
# dockerfilePath = scripts/dr/Dockerfile). PostgreSQL 18 client for pg_dump against Neon (PG 18).
FROM python:3.13-slim

RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl gnupg \
 && install -d /usr/share/postgresql-common/pgdg \
 && curl -fsSL https://www.postgresql.org/media/keys/ACCC4CF8.asc -o /usr/share/postgresql-common/pgdg/apt.postgresql.org.asc \
 && . /etc/os-release \
 && echo "deb [signed-by=/usr/share/postgresql-common/pgdg/apt.postgresql.org.asc] https://apt.postgresql.org/pub/repos/apt ${VERSION_CODENAME}-pgdg main" \
      > /etc/apt/sources.list.d/pgdg.list \
 && apt-get update \
 && apt-get install -y --no-install-recommends postgresql-client-18 \
 && apt-get purge -y curl gnupg && apt-get autoremove -y && rm -rf /var/lib/apt/lists/*

RUN pip install --no-cache-dir boto3==1.43.115 "psycopg[binary]==3.3.4" cryptography==50.0.0  # = movemark-api-py

WORKDIR /app
COPY neon/migrate.py neon/migrate.py
COPY neon/migrations neon/migrations
COPY scripts/dr/backup.py scripts/dr/offsite.py scripts/dr/run_scheduled.sh scripts/dr/

ENV MOVEMARK_PG18_BIN=/usr/lib/postgresql/18/bin PYTHONUNBUFFERED=1
RUN useradd --create-home mmbackup && chmod +x scripts/dr/run_scheduled.sh
USER mmbackup
CMD ["scripts/dr/run_scheduled.sh"]
