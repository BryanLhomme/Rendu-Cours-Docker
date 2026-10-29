#!/usr/bin/env bash
# backup.sh [--cold] : dump logique pg_dump -Fc + sauvegarde brute du volume, rétention des 7 derniers
# Tout passe par des conteneurs, pas de client psql sur l'hôte.
# --cold : arrête la base pendant la copie du volume pour avoir une sauvegarde brute cohérente
set -euo pipefail
export MSYS_NO_PATHCONV=1

DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${DB_USER:-shop}"
DB_NAME="${DB_NAME:-shop}"
VOLUME="${VOLUME:-shopdata_pgdata}"
BACKUP_DIR="${BACKUP_DIR:-$(pwd)/backups}"
KEEP="${KEEP:-7}"
COLD=0
[ "${1:-}" = "--cold" ] && COLD=1

mkdir -p "$BACKUP_DIR"
HOST_DIR="$BACKUP_DIR"
command -v cygpath >/dev/null && HOST_DIR=$(cygpath -m "$BACKUP_DIR")
ts=$(date +%Y%m%d-%H%M%S)

echo "== dump logique"
docker compose exec -T "$DB_SERVICE" pg_dump -U "$DB_USER" -d "$DB_NAME" -Fc > "$BACKUP_DIR/$DB_NAME-$ts.dump"
docker compose exec -T "$DB_SERVICE" pg_restore --list < "$BACKUP_DIR/$DB_NAME-$ts.dump" > /dev/null
echo "   $BACKUP_DIR/$DB_NAME-$ts.dump ($(du -h "$BACKUP_DIR/$DB_NAME-$ts.dump" | cut -f1))"

echo "== sauvegarde brute du volume $VOLUME"
if [ "$COLD" = 1 ]; then
  docker compose stop "$DB_SERVICE" >/dev/null 2>&1
fi
docker run --rm -v "$VOLUME:/data:ro" -v "$HOST_DIR:/backup" alpine:3.20 \
  tar czf "/backup/pgdata-$ts.tar.gz" -C /data .
if [ "$COLD" = 1 ]; then
  docker compose start "$DB_SERVICE" >/dev/null 2>&1
  docker compose up -d --wait "$DB_SERVICE" >/dev/null 2>&1
  echo "   (à froid, base arrêtée pendant la copie)"
else
  echo "   (à chaud : la copie brute peut être incohérente, utiliser --cold)"
fi
echo "   $BACKUP_DIR/pgdata-$ts.tar.gz ($(du -h "$BACKUP_DIR/pgdata-$ts.tar.gz" | cut -f1))"

echo "== rétention : $KEEP derniers de chaque type"
for pattern in "$DB_NAME-*.dump" "pgdata-*.tar.gz"; do
  # shellcheck disable=SC2012,SC2086  # glob voulu sur $pattern
  ls -1t "$BACKUP_DIR"/$pattern 2>/dev/null | tail -n +"$((KEEP + 1))" | while read -r old; do
    echo "   suppression $(basename "$old")"
    rm -f "$old"
  done
done
