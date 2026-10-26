Diagnostic image shopapi:legacy

Construire l'image :

docker build -t shopapi:legacy .

Taille / performance

1. Image énorme
docker image ls shopapi:legacy
shopapi:legacy   1.09GB
Impact : registre saturé, pull lent sur chaque noeud.

2. Image de base ubuntu:22.04 + Node installé à la main
docker history shopapi:legacy
87.7MB ADD file ubuntu / 173MB apt-get install -y nodejs
Impact : on paye une distrib complète alors qu'une image node officielle existe.

3. Outils inutiles installés (curl wget vim git build-essential python3)
docker history shopapi:legacy
393MB RUN apt-get install -y curl wget vim git build-essential python3
Impact : la plus grosse couche de l'image, ne sert à rien au runtime.

4. apt-get update dans une couche séparée et cache apt jamais supprimé
docker history shopapi:legacy
81.4MB RUN apt-get update
hadolint : DL3009 Delete the apt lists (/var/lib/apt/lists) after installing something
Impact : 81 Mo de listes apt pour rien, et cache apt potentiellement périmé.

5. COPY . avant npm install, donc cache cassé à chaque changement de code
echo "// commentaire" >> src/server.js puis docker build -t shopapi:legacy .
#12 COPY . /app DONE / #13 RUN npm install DONE 9.2s
Impact : npm install rejoué à chaque commit, même pour un README.

6. Dépendances de dev dans l'image (npm install sans --omit=dev + nodemon global)
docker run --rm shopapi:legacy ls /app/node_modules/.bin
eslint nodemon ...
Impact : image plus lourde et plus de surface d'attaque.

7. Pas de package-lock.json versionné, npm install au lieu de npm ci
docker run --rm shopapi:legacy ls -la /app
package-lock.json créé pendant le build
Impact : build pas reproductible, les versions changent d'un build à l'autre.

Sécurité

8. Secret en dur dans une variable d'environnement
docker run --rm shopapi:legacy env | grep -i -E 'secret|database'
DATABASE_URL=postgres://shop:S3cret!@db.internal:5432/shop
Impact : mot de passe de la base visible par toute personne qui peut pull l'image.

9. Fichier .env avec des clés copié dans l'image
docker run --rm shopapi:legacy cat /app/.env
AWS_SECRET_ACCESS_KEY=AKIAFAKEFAKEFAKEFAKE
Impact : fuite de clés AWS et des accès base/redis.

10. Dump SQL de prod, Dockerfile et .gitignore dans l'image (pas de .dockerignore)
docker run --rm shopapi:legacy ls -la /app
.env Dockerfile dump-prod-2024.sql .gitignore
Impact : données de prod potentiellement exposées.

11. Conteneur lancé en root
docker run --rm shopapi:legacy id
uid=0(root) gid=0(root) groups=0(root)
Impact : en cas de faille dans l'app, l'attaquant est root dans le conteneur.

12. Versions non épinglées (apt, npm -g, nodesource en curl | bash)
hadolint Dockerfile
DL3008 warning: Pin versions in apt get install
DL3016 warning: Pin versions in npm
DL4006 warning: Set the SHELL option -o pipefail before RUN with a pipe in it
Impact : on exécute un script distant sans contrôle et le build change dans le temps.

Exploitabilité

13. CMD en forme shell, /bin/sh est le PID 1
docker exec legacy-exo ps -ef
PID 1 /bin/sh -c npm start / PID 7 npm start / PID 18 sh -c node src/server.js / PID 19 node src/server.js
hadolint : DL3025 warning: Use arguments JSON notation for CMD and ENTRYPOINT arguments
Impact : SIGTERM n'arrive pas jusqu'à node, le conteneur est tué en SIGKILL.

14. Arrêt brutal
docker stop legacy-exo puis docker inspect legacy-exo --format '{{.State.ExitCode}}'
exit=137
Impact : le code d'arrêt propre de l'app n'est jamais exécuté, rolling updates lentes.

15. NODE_ENV=development en prod
docker inspect shopapi:legacy
ENV NODE_ENV=development
Impact : express plus lent et messages d'erreur trop bavards.

16. Pas de HEALTHCHECK ni de labels
docker inspect shopapi:legacy --format '{{json .Config.Healthcheck}} {{json .Config.Labels}}'
null {"org.opencontainers.image.version":"22.04"}
Impact : Docker ne sait pas si l'app répond, et on ne sait pas quelle version ou quel commit tourne.

17. L'API plante avec la config de l'image
docker run -d --name legacy-exo -p 3001:3000 shopapi:legacy puis curl localhost:3001/products
{"error":"internal error"}
Impact : la DATABASE_URL en dur pointe vers une base injoignable, l'API ne marche pas sans la surcharger.
