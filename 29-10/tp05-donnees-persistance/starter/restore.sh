#!/usr/bin/env bash
# restore.sh FICHIER : restaure un dump .dump (pg_restore) ou une sauvegarde brute .tar.gz du volume
set -euo pipefail
export MSYS_NO_PATHCONV=1

FILE="${1:?usage: restore.sh backups/shop-AAAAMMJJ-HHMMSS.dump | backups/pgdata-AAAAMMJJ-HHMMSS.tar.gz}"
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-shop}"
DB_NAME="${DB_NAME:-shop}"
VOLUME="${VOLUME:-shopdata_pgdata}"
[ -f "$FILE" ] || { echo "fichier $FILE introuvable"; exit 1; }

case "$FILE" in
  *.dump)
    echo "== restauration logique de $FILE"
    docker compose up -d --wait "$DB_SERVICE" >/dev/null 2>&1
    docker compose exec -T "$DB_SERVICE" pg_restore -U "$DB_USER" -d "$DB_NAME" \
      --clean --if-exists --no-owner --exit-on-error < "$FILE"
    ;;
  *.tar.gz)
    echo "== restauration brute de $FILE dans le volume $VOLUME"
    DIR=$(cd "$(dirname "$FILE")" && pwd); NAME=$(basename "$FILE")
    command -v cygpath >/dev/null && DIR=$(cygpath -m "$DIR")
    docker compose stop "$DB_SERVICE" >/dev/null 2>&1 || true
    docker volume create "$VOLUME" >/dev/null
    docker run --rm -v "$VOLUME:/data" -v "$DIR:/backup:ro" alpine:3.20 \
      sh -c "find /data -mindepth 1 -delete && tar xzf /backup/$NAME -C /data"
    docker compose up -d --wait "$DB_SERVICE" >/dev/null 2>&1
    ;;
  *)
    echo "format inconnu : $FILE"; exit 1 ;;
esac

echo "== vérification"
docker compose exec -T "$DB_SERVICE" psql -U "$DB_USER" -d "$DB_NAME" -c \
  "SELECT count(*) AS orders, md5(string_agg(id::text || status, ',' ORDER BY id)) AS checksum FROM orders;"
