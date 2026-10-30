Exercice 7

Le fichier init.sql crée les tables de la base kennelDB (clients, adresses, clients_adresses, chiens, chats) et insère des données.

Le Dockerfile part de l'image mysql et copie init.sql dans le dossier /docker-entrypoint-initdb.d/ pour qu'il soit exécuté au premier lancement.

Construire l'image :

docker build -t kennel-db .

Lancer le conteneur :

docker run -d --name kennel-exo7 kennel-db

Vérifier que les tables sont là :

docker exec -it kennel-exo7 mysql -uroot -proot kennelDB

SHOW TABLES;

SELECT * FROM clients;

Les 5 tables et leurs données sont bien présentes dès le lancement.
