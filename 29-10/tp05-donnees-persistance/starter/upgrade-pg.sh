#!/usr/bin/env bash
# upgrade-pg.sh : montée de version PostgreSQL 14 -> 16 par dump/restore, sur un nouveau volume
# Retour arrière : docker compose -f compose.pg16.yml stop db && docker compose up -d --wait
set -euo pipefail
export MSYS_NO_PATHCONV=1

OLD=(docker compose -f compose.yml)
NEW=(docker compose -f compose.pg16.yml)
DIR="${UPGRADE_DIR:-$(pwd)/upgrade}"
ts=$(date +%Y%m%d-%H%M%S)
SQL_CHECK="SELECT count(*) || ' ' || md5(string_agg(id::text || status, ',' ORDER BY id)) FROM orders"
mkdir -p "$DIR"
if docker volume inspect shopdata_pgdata16 >/dev/null 2>&1; then
  echo "le volume shopdata_pgdata16 existe déjà : montée de version déjà faite ou à nettoyer"
  echo "(docker compose -f compose.pg16.yml down puis docker volume rm shopdata_pgdata16)"
  exit 1
fi
step() { echo; echo "== $(date +%H:%M:%S) $1"; }

step "1. checksum avant (PG14)"
"${OLD[@]}" up -d --wait db >/dev/null 2>&1
"${OLD[@]}" exec -T db psql -U shop -d shop -tAc "SELECT version()"
before=$("${OLD[@]}" exec -T db psql -U shop -d shop -tAc "$SQL_CHECK")
echo "   $before"

step "2. sauvegardes"
"${OLD[@]}" exec -T db pg_dumpall -U shop > "$DIR/dumpall-pg14-$ts.sql"
"${OLD[@]}" exec -T db pg_dump -U shop -d shop -Fc > "$DIR/shop-pg14-$ts.dump"
for f in "$DIR"/*"$ts"*; do echo "   $(du -h "$f" | cut -f1) $(basename "$f")"; done

step "3. arrêt de PG14 (le volume shopdata_pgdata est conservé)"
start=$(date +%s)
"${OLD[@]}" stop db >/dev/null 2>&1
echo "   PG14 arrêté, début de l'indisponibilité"

step "4. PG16 sur le nouveau volume shopdata_pgdata16"
"${NEW[@]}" up -d --wait db >/dev/null 2>&1
"${NEW[@]}" exec -T db psql -U shop -d shop -tAc "SELECT version()"

step "5. restauration"
"${NEW[@]}" exec -T db pg_restore -U shop -d shop --no-owner --exit-on-error < "$DIR/shop-pg14-$ts.dump"
"${NEW[@]}" exec -T db psql -U shop -d shop -qc "ANALYZE"
end=$(date +%s)
echo "   restauré, indisponibilité : $((end - start)) s"

step "6. checksum après (PG16)"
after=$("${NEW[@]}" exec -T db psql -U shop -d shop -tAc "$SQL_CHECK")
echo "   $after"

step "7. verdict"
if [ "$before" = "$after" ]; then
  echo "   OK : checksums identiques ($after), PG16 en service"
  echo "   retour arrière : docker compose -f compose.pg16.yml stop db && docker compose up -d --wait"
else
  echo "   ÉCHEC : avant=$before après=$after"
  echo "   retour arrière automatique sur PG14"
  "${NEW[@]}" stop db >/dev/null 2>&1
  "${OLD[@]}" up -d --wait db >/dev/null 2>&1
  exit 1
fi
