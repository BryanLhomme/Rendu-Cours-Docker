1. Critique du compose existant

1. version: '3' est obsolète, Compose l'ignore et affiche un avertissement.
2. links est obsolète, les services se trouvent déjà par leur nom sur le réseau du projet.
3. Images non épinglées (postgres, redis sans tag) : on prend latest, la version change toute seule et une montée majeure de postgres casse la base.
4. db et redis publient 5432 et 6379 sur toutes les interfaces de l'hôte : la base et le cache sont joignables depuis l'extérieur.
5. Mot de passe postgres en clair (postgres/postgres) dans le fichier versionné, et répété dans les DATABASE_URL.
6. On utilise l'utilisateur et la base postgres par défaut au lieu d'un compte dédié à l'application.
7. command: sh -c "sleep 10 && node src/server.js" : on attend 10 s au hasard au lieu d'attendre que la base soit prête, et sh devient le PID 1 donc SIGTERM n'arrive plus à node.
8. Aucun healthcheck et aucun depends_on avec condition : on ne sait pas si un service est prêt et up --wait ne sert à rien.
9. Un seul réseau par défaut : le front (API) et les données (db, redis) sont au même niveau, rien n'isole la base.
10. Pas de volume nommé pour postgres et redis : les données sont dans des volumes anonymes, perdues ou orphelines au premier docker compose rm.
11. restart incohérent : seulement restart: always sur le worker, rien sur db, redis et api.
12. Pas de limites CPU/mémoire ni de rotation des logs : un service peut prendre toute la machine ou remplir le disque.
13. Pas de reverse proxy : l'API est exposée directement sur 3000.
14. Pas de nom de projet : le nom dépend du dossier, donc des volumes et réseaux différents selon où le dépôt est cloné.
15. Pas de séparation dev/prod : build local partout, pas d'images versionnées tirées d'un registre.

