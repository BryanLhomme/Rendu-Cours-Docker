Exercice 2

Chercher une image du jeu 2048 sur DockerHub :

docker search 2048

J'ai pris l'image oats87/2048

Récupérer l'image :

docker pull oats87/2048

Lancer le conteneur sur le port 8080 :

docker run -d --name jeu-2048 -p 8080:80 oats87/2048

Vérifier que le conteneur tourne :

docker ps

Le jeu s'affiche bien dans le navigateur sur http://localhost:8080
