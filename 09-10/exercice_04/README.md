Exercice 4

Créer le réseau :

docker network create reseau-exo4

Créer le premier conteneur sur ce réseau et rentrer dedans :

docker run -it --name conteneur1 --network reseau-exo4 ubuntu bash

Installer ping :

apt-get update

apt-get install -y iputils-ping

Sortir du conteneur :

exit

Sauvegarder le conteneur en image :

docker commit conteneur1 ubuntu-ping

Créer le second conteneur à partir de cette image, sur le même réseau :

docker run -dit --name conteneur2 --network reseau-exo4 ubuntu-ping bash

Relancer le premier conteneur :

docker start conteneur1

Vérifier que les deux conteneurs sont sur le réseau :

docker network inspect reseau-exo4

Tester le ping dans les deux sens avec le nom du conteneur :

docker exec conteneur1 ping -c 3 conteneur2

docker exec conteneur2 ping -c 3 conteneur1

Les deux ping passent (3 paquets envoyés, 3 reçus).
