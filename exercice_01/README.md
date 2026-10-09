Exercice 1

Créer le conteneur Ubuntu et rentrer dedans :

docker run -it --name conteneur-ubuntu ubuntu bash

Mettre à jour les paquets :

apt-get update

Installer NGINX :

apt-get install -y nginx

Sortir du conteneur :

exit

Sauvegarder le conteneur en image :

docker commit conteneur-ubuntu ubuntu-nginx

Vérifier que l'image existe :

docker images ubuntu-nginx
