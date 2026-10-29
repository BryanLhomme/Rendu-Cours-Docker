#!/usr/bin/env bash
# Génère une CA interne et un certificat serveur pour registry.local (dans un conteneur alpine)
set -euo pipefail
mkdir -p certs
MSYS_NO_PATHCONV=1 docker run --rm -v "$(pwd)/certs:/certs" -w /certs alpine:3.20 sh -c '
apk add --no-cache openssl >/dev/null
openssl req -x509 -newkey rsa:4096 -nodes -sha256 -days 365 \
  -keyout ca.key -out ca.crt -subj "/CN=Shop SAS Internal CA"
openssl req -newkey rsa:2048 -nodes -sha256 \
  -keyout registry.key -out registry.csr -subj "/CN=registry.local"
printf "subjectAltName=DNS:registry.local,DNS:localhost,IP:127.0.0.1\nextendedKeyUsage=serverAuth\n" > san.ext
openssl x509 -req -in registry.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -days 365 -sha256 -extfile san.ext -out registry.crt
rm registry.csr san.ext
chmod 644 *.crt registry.key
openssl x509 -in registry.crt -noout -ext subjectAltName'
