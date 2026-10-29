1. Anatomie du stockage

Stack du TP04 démarrée (dossier ../../tp04-compose-entreprise/starter) :

docker compose -f compose.yml up -d --wait
docker inspect $(docker compose ps -q db) --format "{{json .Mounts}}" | jq

volume  shop_pgdata  /var/lib/docker/volumes/shop_pgdata/_data -> /var/lib/postgresql/data  rw
bind    .../starter/db/init.sql -> /docker-entrypoint-initdb.d/01-init.sql  ro
bind    .../starter/secrets/db_password.txt -> /run/secrets/db_password  ro

docker volume inspect shop_pgdata

"Mountpoint": "/var/lib/docker/volumes/shop_pgdata/_data", "Driver": "local", labels com.docker.compose.project=shop et com.docker.compose.volume=pgdata

docker system df -v liste les volumes avec leur taille et le nombre de conteneurs qui les utilisent (LINKS).

Writable layer vs volume :

docker exec shop-db-1 touch /tmp/x
docker diff shop-db-1

C /tmp
A /tmp/x
C /run/postgresql
A /run/postgresql/.s.PGSQL.5432
A /run/postgresql/.s.PGSQL.5432.lock

/tmp/x est écrit dans la couche du conteneur (writable layer), qui est supprimée avec le conteneur. Les fichiers de la base ne sont pas dans docker diff : /var/lib/postgresql/data est un volume, stocké à part dans /var/lib/docker/volumes/shop_pgdata/_data de la VM Docker Desktop, et il survit au conteneur.

Cycle de vie de pgdata, testé sur une copie de la stack (docker compose -p shop-copy -f compose.yml, seulement db) après avoir inséré une ligne test-copie :

docker compose -p shop-copy down        volume shop-copy_pgdata gardé, la ligne est encore là au up suivant
docker compose -p shop-copy rm -f db    volume gardé
docker volume prune -f --filter label=com.docker.compose.project=shop-copy
                                        volume gardé : prune ne supprime que les volumes anonymes par défaut
docker volume prune -af --filter label=com.docker.compose.project=shop-copy
                                        volume supprimé (47.92MB) : avec -a tous les volumes non utilisés partent, même nommés
docker compose -p shop-copy down -v     Volume shop-copy_pgdata Removed

J'ai mis --filter sur les prune pour ne toucher que la copie : sans filtre, docker volume prune -a aurait aussi supprimé tous les autres volumes inutilisés de la machine.

Volume anonyme :

docker run -d --name tp05-anon -e POSTGRES_PASSWORD=x postgres:16.4-alpine
docker inspect tp05-anon --format "{{range .Mounts}}{{.Type}} {{.Name}} -> {{.Destination}}{{end}}"
volume f2962eb21f95aac3e79c840b3fddc269dbf02609f7f67ad5112f91fb7e84a6ef -> /var/lib/postgresql/data

L'image postgres déclare VOLUME /var/lib/postgresql/data, donc même sans -v Docker crée un volume avec un nom aléatoire.

docker rm -f tp05-anon     le volume f2962eb2... est toujours là (docker volume ls), orphelin
docker rm -f -v tp05-anon  le volume anonyme est supprimé avec le conteneur

C'est un piège parce qu'on croit que les données sont dans le conteneur : un nouveau docker run crée un nouveau volume vide, la base semble perdue alors qu'elle traîne dans un volume au nom illisible, et ces volumes s'accumulent et remplissent le disque. Ou au contraire un rm -v ou un prune efface la base sans prévenir.

Bind mount vs volume nommé vs tmpfs :

- bind mount : un dossier de l'hôte, pour le code en dev, des fichiers de config, ou un secret. Les droits et le chemin dépendent de l'hôte.
- volume nommé : géré par Docker, pour les données d'une base ou de tout service avec un état. Portable, sauvegardable avec un conteneur, et initialisé avec le contenu de l'image.
- tmpfs : en mémoire, perdu à l'arrêt, pour les fichiers temporaires, avec read_only (comme au TP04) ou pour des données sensibles qui ne doivent pas toucher le disque.

Sur Docker Desktop (Windows/macOS) les conteneurs tournent dans une VM Linux. Un volume nommé est sur le disque de la VM, donc rapide. Un bind mount d'un dossier C:\ ou /Users passe par le partage de fichiers entre l'hôte et la VM, beaucoup plus lent pour les petits fichiers (node_modules, base de données), et sans événements inotify (c'est pour ça que node --watch ne marchait pas avec un bind mount au TP04). Il ne faut jamais mettre les données d'une base sur un bind mount Windows.

init.sql pas rejoué :

docker compose -f compose.yml restart db
docker compose -f compose.yml logs db
PostgreSQL Database directory appears to contain a database; Skipping initialization

L'entrypoint de postgres n'exécute docker-entrypoint-initdb.d que si le répertoire de données est vide, au tout premier démarrage. Pour forcer une ré-initialisation il faut repartir d'un volume vide : docker compose down -v (ou docker volume rm shop_pgdata) puis docker compose up. Toutes les données sont perdues, donc en vrai on passe par des migrations (service migrate du TP04) plutôt que de modifier init.sql.

