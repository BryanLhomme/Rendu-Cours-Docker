# Rapport d'incident — préprod Shop SAS

**Heure de début** : 9h12 · **Heure de résolution** : 9h45 · **Impact** : préprod indisponible

## Chronologie du diagnostic

| Heure | Symptôme observé | Commande / preuve | Hypothèse | Résultat |
|-------|------------------|-------------------|-----------|----------|
| 9h20 | La stack ne démarre pas | `docker compose config` : `can't set container_name and api as container name must be unique` | `container_name` fixe incompatible avec `replicas: 2` | Confirmé, `container_name` supprimé |
| 9h22 | Build impossible | `docker compose up -d` : `path ".../tp04-compose-entreprise/solution/apps/shopapi" not found` | Mauvais chemin, le dossier s'appelle `starter` | Confirmé, chemins du build et de `init.sql` corrigés |
| 9h25 | api en `Exited (1)` | `docker compose logs api` : `Cannot find module '/app/server.js'` | `command` écrase le CMD de l'image, le fichier est `src/server.js` | Confirmé, `command` supprimée |
| 9h26 | Logs db en erreur toutes les 5 s | `docker compose logs db` : `FATAL: role "postgres" does not exist` | Healthcheck lancé avec l'utilisateur `postgres` au lieu de `shop` | Confirmé, `pg_isready -U shop -d shop` |
| 9h27 | front reste `Created` | `docker compose up -d` : `error mounting ".../nginx" to rootfs at "/etc/nginx/conf.d/default.conf": not a directory` | Le dossier `nginx` est monté sur un fichier | Confirmé, montage de `./nginx/default.conf` |
| 9h28 | api `unhealthy` | `docker inspect incident-api-1 --format '{{json .State.Health.Log}}'` : `wget: can't connect to remote host (127.0.0.1): Connection refused` et `netstat -tln` : écoute sur `:::8080` | `PORT: 8080` alors que le HEALTHCHECK de l'image vise le port 3000 | Confirmé, `PORT` supprimé (port 3000 par défaut) |
| 9h30 | api ne trouve pas ses dépendances | `docker exec incident-api-1 getent hosts databse db redis` : aucune réponse | api seulement sur `public`, db sur `backend`, faute de frappe `databse` | Confirmé, api sur `public` + `backend`, hôte `db` |
| 9h31 | redis injoignable par son nom | `docker inspect incident-redis-1 --format '{{.HostConfig.NetworkMode}}'` : `host` | En `network_mode: host`, redis n'est sur aucun réseau du projet, pas de DNS | Confirmé, redis sur `backend` |
| 9h32 | redis refuse les commandes | `redis-cli -h redis ping` : `NOAUTH Authentication required.` | `--requirepass r3dis` mais `REDIS_URL` sans mot de passe | Confirmé, `redis://:r3dis@redis:6379` |
| 9h34 | 8081 ne répond pas même avec front lancé | test : conteneur sur un réseau `--internal` avec `-p 8099:80`, `curl localhost:8099` en échec, `docker port` vide | `public` en `internal: true` empêche la publication du port 8081 | Confirmé, `public` normal et `backend` en `internal: true` |
| 9h36 | nginx renvoie vers lui-même | `default.conf` : `proxy_pass http://localhost:3000` | Dans le conteneur front, `localhost` est front, pas l'api | Confirmé, `proxy_pass http://api:3000` |
| 9h40 | front et redis sans état de santé, démarrage non ordonné | `docker compose ps` : pas de `(healthy)` sur front et redis | Pas de healthcheck, `depends_on` sans condition | Healthchecks ajoutés, `depends_on` en `service_healthy` |
| 9h45 | Résolu | `docker compose up -d --build --wait`, `docker compose ps` tout `healthy`, `curl -D - localhost:8081/products` : `X-Cache: MISS` puis `X-Cache: HIT` | | OK |

## Anomalies trouvées

| # | Fichier / service | Anomalie | Correction | Catégorie (réseau / config / cycle de vie / stockage) |
|---|-------------------|----------|------------|----------|
| 1 | compose.yml / api | `container_name: api` avec `deploy.replicas: 2` | suppression de `container_name` | cycle de vie |
| 2 | compose.yml / api | build sur `tp04-compose-entreprise/solution/apps/shopapi` qui n'existe pas | `tp04-compose-entreprise/starter/apps/shopapi` | config |
| 3 | compose.yml / api | `command: node server.js`, le fichier est `src/server.js` | suppression de `command`, on garde le CMD de l'image | config |
| 4 | compose.yml / api | `PORT: 8080`, nginx et le HEALTHCHECK de l'image attendent 3000 | suppression de `PORT` | config |
| 5 | compose.yml / api | `DATABASE_URL` vers `databse` (faute de frappe) | hôte `db` | config |
| 6 | compose.yml / api | api seulement sur `public`, ne voit pas db ni redis | api sur `public` et `backend` | réseau |
| 7 | compose.yml / api | `REDIS_URL` sans le mot de passe défini par `--requirepass` | `redis://:r3dis@redis:6379` | sécurité |
| 8 | compose.yml / db | healthcheck `pg_isready -U postgres`, rôle inexistant | `pg_isready -U shop -d shop` | config |
| 9 | compose.yml / db | `init.sql` monté depuis `tp04-compose-entreprise/solution/db` qui n'existe pas | `tp04-compose-entreprise/starter/db/init.sql` | stockage |
| 10 | compose.yml / redis | `network_mode: host` : pas sur le réseau du projet, pas de résolution DNS, et exposé sur l'hôte | redis sur `backend` | réseau |
| 11 | compose.yml / networks | `public` en `internal: true` : le port 8081 de front ne peut pas être publié | `public` normal | réseau |
| 12 | compose.yml / networks | `backend` (db, redis) pas isolé | `backend` en `internal: true` | sécurité |
| 13 | compose.yml / front | dossier `./nginx` monté sur le fichier `default.conf` | `./nginx/default.conf:/etc/nginx/conf.d/default.conf:ro` | stockage |
| 14 | default.conf | `proxy_pass http://localhost:3000` : localhost est le conteneur front | `proxy_pass http://api:3000` | réseau |
| 15 | compose.yml / front, redis | pas de healthcheck, `depends_on` sans condition | healthchecks + `condition: service_healthy` | cycle de vie |

## Pourquoi ça n'a pas été détecté avant ?

Le compose a été modifié et poussé sans être lancé : aucune validation (`docker compose config` aurait déjà refusé le fichier à cause de `container_name` + `replicas`), aucun test après démarrage, pas de relecture. Plusieurs erreurs ne se voient qu'à l'exécution (chemin de build, réseaux, port, mot de passe Redis) et sans healthcheck partout ni `--wait`, `docker compose up -d` rend la main sans signaler que la stack est cassée.

## Actions de prévention

1. CI sur chaque modification du compose : `docker compose config -q` puis `docker compose up -d --build --wait` et un smoke test (`curl localhost:8081/products` deux fois, vérifier `X-Cache: HIT`).
2. Relecture obligatoire (merge request) de tout changement sur `compose.yml` et la conf nginx, avec une checklist réseau : quel service est sur quel réseau, quels ports sont publiés, quels réseaux sont `internal`.
3. Healthcheck sur tous les services, `depends_on` avec `condition: service_healthy`, et déploiement uniquement avec `docker compose up -d --wait` pour qu'une stack malade échoue tout de suite au lieu de partir silencieusement.
