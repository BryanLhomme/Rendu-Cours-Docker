#!/usr/bin/env bash
# smoke-test.sh : vérifie la stack démarrée (passe par Traefik, Host api.localhost)
set -euo pipefail
BASE="${BASE_URL:-http://localhost}"
HOST="${API_HOST:-api.localhost}"
CURL=(curl -s -m 5 -H "Host: $HOST")
fail() { echo "ECHEC : $1"; exit 1; }

echo "1. /ready"
ready=$("${CURL[@]}" "$BASE/ready")
echo "   $ready"
echo "$ready" | grep -q '"db":"ok"' && echo "$ready" | grep -q '"redis":"ok"' || fail "/ready ne répond pas db ok et redis ok"

echo "2. /products avec cache"
"${CURL[@]}" -o /dev/null "$BASE/products"
cache=$("${CURL[@]}" -D - -o /dev/null "$BASE/products" | tr -d '\r' | awk -F': ' 'tolower($1)=="x-cache"{print $2}')
echo "   X-Cache: $cache"
[ "$cache" = "HIT" ] || fail "le 2e appel /products devrait être un HIT"

echo "3. création d'une commande"
product_id=$(( (RANDOM % 3) + 1 ))
order=$("${CURL[@]}" -X POST -H 'Content-Type: application/json' -d "{\"productId\":$product_id,\"quantity\":2}" "$BASE/orders")
echo "   $order"
echo "$order" | grep -q '"status":"pending"' || fail "commande non créée"

echo "4. commande confirmée par le worker"
for _ in $(seq 1 15); do
  pending=$(docker compose exec -T db psql -U shop -d shop -tAc "SELECT count(*) FROM orders WHERE product_id=$product_id AND status='pending'")
  if [ "$pending" = "0" ]; then
    last=$(docker compose exec -T db psql -U shop -d shop -tAc "SELECT id, status FROM orders WHERE product_id=$product_id ORDER BY id DESC LIMIT 1")
    echo "   dernière commande du produit $product_id : $last"
    echo "SMOKE TEST OK"
    exit 0
  fi
  sleep 1
done
fail "la commande est toujours pending après 15 s"
