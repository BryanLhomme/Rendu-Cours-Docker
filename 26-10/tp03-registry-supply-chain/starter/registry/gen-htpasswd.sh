#!/usr/bin/env bash
# Crée le fichier htpasswd (bcrypt) avec les comptes ci et dev
set -euo pipefail
mkdir -p auth
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn ci ci-push-2024 > auth/htpasswd
docker run --rm --entrypoint htpasswd httpd:2.4 -Bbn dev dev-pull-2024 >> auth/htpasswd
cat auth/htpasswd
