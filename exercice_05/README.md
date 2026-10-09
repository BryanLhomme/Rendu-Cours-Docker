Exercice 5

Créer le réseau :

docker network create reseau-exo5

Créer le volume pour garder les données de MySQL :

docker volume create donnees-mysql

Lancer le conteneur MySQL avec une base et un utilisateur (pas de -p donc il n'est pas accessible depuis la machine hôte) :

docker run -d --name mysql-exo5 --network reseau-exo5 --restart always -v donnees-mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=exo5 -e MYSQL_USER=bryan -e MYSQL_PASSWORD=bryan mysql

Lancer le conteneur Adminer sur le port 8080 :

docker run -d --name adminer-exo5 --network reseau-exo5 --restart always -p 8080:8080 adminer

Se connecter à Adminer sur http://localhost:8080 avec :

Serveur : mysql-exo5
Utilisateur : bryan
Mot de passe : bryan
Base de données : exo5

Dans Adminer, créer la table et insérer les enregistrements avec la requête SQL du fichier table.sql.

Vérifications

Supprimer puis recréer le conteneur MySQL :

docker rm -f mysql-exo5

docker run -d --name mysql-exo5 --network reseau-exo5 --restart always -v donnees-mysql:/var/lib/mysql -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=exo5 -e MYSQL_USER=bryan -e MYSQL_PASSWORD=bryan mysql

La table etudiants et ses 3 enregistrements sont toujours là dans Adminer.

Simuler une panne du conteneur MySQL :

docker exec mysql-exo5 bash -c "kill 1"

docker ps

Le conteneur a redémarré tout seul.

Bonus

Le fichier compose.yaml lance les deux services en une seule commande :

docker compose up -d
