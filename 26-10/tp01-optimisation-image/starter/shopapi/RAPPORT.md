TP01 Rapport

Le Dockerfile d'origine est gardé dans Dockerfile.legacy.

Générer le package-lock.json :

docker run --rm -v "%cd%:/app" -w /app node:20-alpine npm install --package-lock-only

Mesurer le cache sur l'image legacy :

docker build -t shopapi:legacy -f Dockerfile.legacy .
echo // commentaire >> src/server.js
docker build -t shopapi:legacy -f Dockerfile.legacy .

npm install est rejoué parce que COPY . /app est fait avant, donc dès qu'un fichier change la couche COPY change et toutes les couches d'après sont refaites.

Ordre des couches idéal :

image de base
package.json + package-lock.json
npm ci
code source
config (user, healthcheck, cmd)

Construire la nouvelle image :

docker build --build-arg APP_VERSION=1.4.2 --build-arg GIT_SHA=91dcfcb -t shopapi:1.4.2 .

Lancer seulement les tests :

docker build --target test -t shopapi:test .

tests 1 / pass 1 / fail 0 / lint ok

Vérifier la conformité :

docker image ls shopapi
docker run --rm shopapi:1.4.2 id
docker run --rm shopapi:1.4.2 ls -la /app
docker inspect shopapi:1.4.2 --format "{{json .Config.Labels}}"
docker run -d --name api -p 3000:3000 shopapi:1.4.2
docker inspect api --format "{{.State.Health.Status}}"
curl -s localhost:3000/products
docker stop api

Résultats :

uid=1000(node) gid=1000(node)
/app contient seulement node_modules, package.json et src
{"org.opencontainers.image.revision":"91dcfcb","org.opencontainers.image.source":"https://github.com/BryanLhomme/Rendu-Cours-Docker","org.opencontainers.image.title":"shopapi","org.opencontainers.image.version":"1.4.2"}
healthy
[{"id":1,"name":"Clavier mécanique","price":89.9,"stock":12},{"id":2,"name":"Écran 27\"","price":249,"stock":4},{"id":3,"name":"Souris sans fil","price":29.5,"stock":40}]

Le legacy est tué en SIGKILL (exit 137) parce que le PID 1 est /bin/sh qui ne transmet pas SIGTERM à node. Avec le CMD en forme exec, node est le PID 1, reçoit SIGTERM et s'arrête proprement (exit 0).

Tableau avant / après :

                              legacy          1.4.2
taille (du -sxh /)            767 Mo          152.5 Mo
taille compressée             286 Mo          50.9 Mo
couches (docker history)      18              21
rebuild après changement code 14.9 s          3.0 s (npm ci en cache)
utilisateur                   root            node (uid 1000)
temps d'arrêt                 1.5 s, exit 137 1.0 s, exit 0

hadolint :

docker run --rm -i hadolint/hadolint < Dockerfile

Sortie vide.

Dockerfile final :

FROM node:20.20.2-alpine3.22 AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev --no-audit --no-fund

FROM node:20.20.2-alpine3.22 AS test
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --no-audit --no-fund
COPY src ./src
COPY test ./test
RUN npm test && npm run lint

FROM node:20.20.2-alpine3.22 AS runtime
ARG APP_VERSION=dev
ARG GIT_SHA=local
LABEL org.opencontainers.image.title="shopapi" \
      org.opencontainers.image.version="${APP_VERSION}" \
      org.opencontainers.image.revision="${GIT_SHA}" \
      org.opencontainers.image.source="https://github.com/BryanLhomme/Rendu-Cours-Docker"
ENV NODE_ENV=production \
    APP_VERSION=${APP_VERSION}
WORKDIR /app
COPY --from=deps --chown=node:node /app/node_modules ./node_modules
COPY --from=test --chown=node:node /app/package.json ./
COPY --chown=node:node src ./src
# hadolint ignore=DL3066
USER node
EXPOSE 3000
HEALTHCHECK --interval=5s --timeout=3s --start-period=5s --retries=3 \
  CMD ["wget", "-q", "--spider", "http://127.0.0.1:3000/health"]
CMD ["node", "src/server.js"]

Le COPY --from=test oblige le build à passer par l'étape de test.
