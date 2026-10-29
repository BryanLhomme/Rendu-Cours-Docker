#!/usr/bin/env bash
# release-gate.sh IMAGE [--push REGISTRY_IMAGE]
# Refuse la publication d'une image qui ne respecte pas la politique Shop SAS.
# Si l'image passe : push, signature cosign, attestation SBOM.
# Les outils (trivy, syft, crane, cosign) tournent en conteneur.
# Variables : WORK_DIR (cosign.key, sbom, config docker), REGISTRY_NETWORK, CA_FILE
set -euo pipefail
export MSYS_NO_PATHCONV=1

IMAGE="${1:?usage: release-gate.sh IMAGE [--push REGISTRY_IMAGE]}"
PUSH_REF=""
if [ "${2:-}" = "--push" ]; then
  PUSH_REF="${3:?--push demande REGISTRY_IMAGE}"
fi

WORK_DIR="${WORK_DIR:-$(pwd)/supply}"
REGISTRY_NETWORK="${REGISTRY_NETWORK:-shop-registry_default}"
CA_FILE="${CA_FILE:-$(pwd)/registry/certs/ca.crt}"
mkdir -p "$WORK_DIR"
if command -v cygpath >/dev/null; then
  WORK_DIR=$(cygpath -m "$WORK_DIR"); CA_FILE=$(cygpath -m "$CA_FILE")
fi
SOCK=(-v /var/run/docker.sock:/var/run/docker.sock)
TRIVY=(docker run --rm "${SOCK[@]}" -v trivy-cache:/root/.cache aquasec/trivy:0.58.1)
SYFT=(docker run --rm "${SOCK[@]}" anchore/syft:v1.18.1)
REG=(--network "$REGISTRY_NETWORK" -v "$CA_FILE:/ca.crt:ro" -e SSL_CERT_FILE=/ca.crt
     -v "$WORK_DIR:/work" -w /work -e DOCKER_CONFIG=/work/dc)
CRANE=(docker run --rm "${REG[@]}" gcr.io/go-containerregistry/crane:v0.21.0)
COSIGN=(docker run --rm "${REG[@]}" -e COSIGN_PASSWORD="${COSIGN_PASSWORD:-}" ghcr.io/sigstore/cosign/cosign:v2.4.1)

errors=0
ok()   { echo "  OK    $1"; }
fail() { echo "  REFUS $1"; errors=$((errors + 1)); }

echo "== Porte de release : $IMAGE"
docker image inspect "$IMAGE" >/dev/null 2>&1 || { echo "image $IMAGE introuvable"; exit 2; }

echo "-- labels OCI"
for label in version revision source; do
  value=$(docker image inspect "$IMAGE" --format "{{index .Config.Labels \"org.opencontainers.image.$label\"}}")
  if [ -n "$value" ]; then ok "org.opencontainers.image.$label=$value"; else fail "label org.opencontainers.image.$label absent"; fi
done

echo "-- utilisateur"
user=$(docker image inspect "$IMAGE" --format '{{.Config.User}}')
if [ -z "$user" ] || [ "${user%%:*}" = "root" ] || [ "${user%%:*}" = "0" ]; then
  fail "conteneur lancé en root (USER='${user}')"
else
  ok "USER=$user"
fi

echo "-- healthcheck"
hc=$(docker image inspect "$IMAGE" --format '{{if .Config.Healthcheck}}{{json .Config.Healthcheck.Test}}{{end}}')
if [ -n "$hc" ] && [ "$hc" != '["NONE"]' ]; then ok "HEALTHCHECK $hc"; else fail "pas de HEALTHCHECK"; fi

echo "-- CVE HIGH/CRITICAL corrigeables"
if "${TRIVY[@]}" image -q --scanners vuln --severity HIGH,CRITICAL --ignore-unfixed --exit-code 1 "$IMAGE" >/tmp/gate-vuln.txt 2>&1; then
  ok "aucune CVE HIGH/CRITICAL corrigeable"
else
  grep -E '^Total|^[^ ].*\(' /tmp/gate-vuln.txt | sed 's/^/        /' || true
  fail "CVE HIGH/CRITICAL corrigeables présentes"
fi

echo "-- secrets"
if "${TRIVY[@]}" image -q --scanners secret --exit-code 1 "$IMAGE" >/tmp/gate-secret.txt 2>&1; then
  ok "aucun secret détecté"
else
  grep -E '^(CRITICAL|HIGH|MEDIUM|LOW):| /' /tmp/gate-secret.txt | sed 's/^/        /' || true
  fail "secret détecté dans l'image"
fi

if [ "$errors" -gt 0 ]; then
  echo "== REFUSÉ : $errors problème(s), l'image n'est pas publiée"
  exit 1
fi
echo "== ACCEPTÉ"

[ -z "$PUSH_REF" ] && exit 0

echo "-- SBOM"
"${SYFT[@]}" "$IMAGE" -o spdx-json -q > "$WORK_DIR/sbom.json"
ok "sbom.json généré"

echo "-- push $PUSH_REF"
docker save "$IMAGE" -o "$WORK_DIR/image.tar"
"${CRANE[@]}" push image.tar "$PUSH_REF" >/dev/null 2>&1
rm -f "$WORK_DIR/image.tar"
digest=$("${CRANE[@]}" digest "$PUSH_REF")
ref="${PUSH_REF%:*}@$digest"
ok "poussé $ref"

echo "-- signature et attestation (par digest)"
"${COSIGN[@]}" sign --yes --tlog-upload=false --key cosign.key "$ref" >/dev/null 2>&1
"${COSIGN[@]}" attest --yes --tlog-upload=false --key cosign.key --type spdxjson --predicate sbom.json "$ref" >/dev/null 2>&1
"${COSIGN[@]}" verify --insecure-ignore-tlog=true --key cosign.pub "$ref" >/dev/null 2>&1
ok "signé et vérifié"
echo "== Publié : $ref"
