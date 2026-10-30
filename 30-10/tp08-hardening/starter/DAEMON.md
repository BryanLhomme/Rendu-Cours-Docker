# daemon.json

- `no-new-privileges: true` : appliqué à tous les conteneurs, même ceux lancés à la main sans l'option. Un binaire setuid ne peut plus élever les privilèges.
- `icc: false` : coupe la communication entre conteneurs sur le réseau bridge par défaut (`docker0`). Un conteneur compromis lancé avec un simple `docker run` ne peut plus scanner les autres.
- `live-restore: true` : les conteneurs continuent de tourner pendant un redémarrage ou une mise à jour du daemon, pas de coupure de prod.
- `log-driver` + `log-opts` : rotation des logs par défaut (3 fichiers de 10 Mo) pour que les logs ne remplissent pas le disque, même pour un conteneur sans configuration de logs.
- `userns-remap: default` : root dans un conteneur devient un utilisateur non privilégié de l'hôte (utilisateur `dockremap`, uid à partir de 100000). Une évasion du conteneur ne donne plus root sur l'hôte.

Effet de bord de `icc: false` : il ne touche que le bridge par défaut. La stack utilise des réseaux définis par compose (`front`, `back`, `socket`), où les conteneurs continuent de se parler, donc rien ne change pour elle. Seuls les conteneurs lancés sans réseau et qui comptent sur les anciens `--link` ne se joignent plus.

Effet de bord de `userns-remap` sur les volumes existants : Docker utilise un nouveau dossier de données (`/var/lib/docker/100000.100000`), les images et volumes existants ne sont plus visibles. Et si on recopie les volumes, leurs fichiers appartiennent aux anciens uid (postgres 70, redis 999) alors que le conteneur les voit maintenant comme 100070, 100999 : PostgreSQL refuse de démarrer (le répertoire de données n'appartient pas au bon utilisateur). Il faut faire un `chown` décalé de 100000 sur les volumes, ou restaurer les données depuis un dump. Les bind mounts posent le même problème, et `--privileged` ou `--network host` demandent `--userns=host`.

Alternative : Docker en mode rootless, où le daemon lui-même tourne sans root. Sous Docker Desktop, ce fichier se règle dans Settings > Docker Engine.
