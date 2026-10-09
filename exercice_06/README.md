Exercice 6

J'ai mis mon site dans le dossier site (fichier index.html).

Lancer un conteneur NGINX en branchant le dossier site sur le dossier du serveur web :

docker run -d --name site-exo6 -p 8080:80 -v "%cd%\site:/usr/share/nginx/html" nginx

Le site s'affiche dans le navigateur sur http://localhost:8080

Quand je modifie index.html sur mon PC et que je recharge la page, la modification apparaît directement, sans relancer le conteneur.
