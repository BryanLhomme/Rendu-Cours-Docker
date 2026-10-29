#!/usr/bin/env bash
# retention.sh REPO N : garde les N tags non semver les plus récents, supprime les autres
# Variables : REGISTRY (défaut https://registry.local:5000), REG_USER, REG_PASS
set -euo pipefail
REPO="${1:?usage: retention.sh REPO N}"
KEEP="${2:?usage: retention.sh REPO N}"
REGISTRY="${REGISTRY:-https://registry.local:5000}"
AUTH="${REG_USER:?REG_USER manquant}:${REG_PASS:?REG_PASS manquant}"
ACCEPT="application/vnd.oci.image.index.v1+json,application/vnd.oci.image.manifest.v1+json,application/vnd.docker.distribution.manifest.list.v2+json,application/vnd.docker.distribution.manifest.v2+json"

tags=$(curl -sf -u "$AUTH" "$REGISTRY/v2/$REPO/tags/list" | jq -r '.tags[]?')

# tags hors semver (les X.Y.Z sont toujours gardés), avec leur date de création
candidates=""
for tag in $tags; do
  if [[ "$tag" =~ ^v?[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    continue
  fi
  manifest=$(curl -sf -u "$AUTH" -H "Accept: $ACCEPT" "$REGISTRY/v2/$REPO/manifests/$tag")
  config=$(echo "$manifest" | jq -r '.config.digest // .manifests[0].digest')
  if echo "$manifest" | jq -e '.manifests' >/dev/null; then
    sub=$(curl -sf -u "$AUTH" -H "Accept: $ACCEPT" "$REGISTRY/v2/$REPO/manifests/$config")
    config=$(echo "$sub" | jq -r '.config.digest')
  fi
  created=$(curl -sfL -u "$AUTH" "$REGISTRY/v2/$REPO/blobs/$config" | jq -r '.created // "1970-01-01T00:00:00Z"')
  candidates+="$created $tag"$'\n'
done

to_delete=$(printf '%s' "$candidates" | sort -r | tail -n +"$((KEEP + 1))" | awk '{print $2}')

deleted=""
for tag in $to_delete; do
  digest=$(curl -sI -u "$AUTH" -H "Accept: $ACCEPT" "$REGISTRY/v2/$REPO/manifests/$tag" \
    | awk -F': ' 'tolower($1)=="docker-content-digest"{print $2}' | tr -d '\r')
  if [ -z "$digest" ] || [[ " $deleted " == *" $digest "* ]]; then
    echo "$REPO:$tag déjà supprimé (même manifeste qu'un autre tag)"
    continue
  fi
  echo "suppression $REPO:$tag ($digest)"
  curl -sf -u "$AUTH" -X DELETE "$REGISTRY/v2/$REPO/manifests/$digest" -o /dev/null
  deleted+=" $digest"
done
echo "tags restants : $(curl -sf -u "$AUTH" "$REGISTRY/v2/$REPO/tags/list" | jq -c '.tags')"
