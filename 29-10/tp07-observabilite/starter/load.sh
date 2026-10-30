#!/usr/bin/env bash
# load.sh [N] : envoie N requêtes à l'API via Traefik (catalogue, commandes, et ~10 % de commandes invalides en 500)
set -euo pipefail
N="${1:-1000}"
URL="${URL:-http://localhost}"
HOST="${HOST_HEADER:-api.localhost}"
for i in $(seq 1 "$N"); do
  case $((i % 10)) in
    0) body='{"productId":999,"quantity":1}' ;;   # produit inexistant : erreur de clé étrangère -> 500
    1|2|3) body="{\"productId\":$(( (i % 3) + 1 )),\"quantity\":$(( (i % 4) + 1 ))}" ;;
    *) body="" ;;
  esac
  if [ -n "$body" ]; then
    curl -s -o /dev/null -H "Host: $HOST" -H 'Content-Type: application/json' -d "$body" "$URL/orders" &
  else
    curl -s -o /dev/null -H "Host: $HOST" "$URL/products" &
  fi
  if (( i % 20 == 0 )); then wait; fi
done
wait
echo "$N requêtes envoyées"
