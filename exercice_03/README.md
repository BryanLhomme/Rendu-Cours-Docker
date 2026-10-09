Exercice 3

J'ai créé une page d'accueil perso dans le fichier index.html.

Lancer un conteneur NGINX sur le port 8081 :

docker run -d --name site-exo3 -p 8081:80 nginx

Copier ma page dans le conteneur à la place de la page par défaut :

docker cp index.html site-exo3:/usr/share/nginx/html/index.html

Le site s'affiche bien dans le navigateur sur http://localhost:8081
