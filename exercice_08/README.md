Exercice 8

API Spring Boot avec un CRUD sur des chiens (nom, race, âge), connectée à une base MySQL avec Hibernate.

Créer le réseau :

docker network create reseau-exo8

Lancer la base de données MySQL :

docker run -d --name mysql-exo8 --network reseau-exo8 -p 3306:3306 -e MYSQL_ROOT_PASSWORD=root -e MYSQL_DATABASE=dogsdb -e MYSQL_USER=bryan -e MYSQL_PASSWORD=bryan mysql

Construire l'image de l'API :

docker build -t dogs-api .

Lancer l'API :

docker run -d --name api-exo8 --network reseau-exo8 -p 8080:8080 -e DB_HOST=mysql-exo8 dogs-api

Tester les endpoints :

Ajouter un chien :

curl -X POST http://localhost:8080/api/v1/dogs -H "Content-Type: application/json" -d "{\"name\":\"Rex\",\"breed\":\"Berger allemand\",\"age\":5}"

Lister les chiens :

curl http://localhost:8080/api/v1/dogs

Récupérer un chien :

curl http://localhost:8080/api/v1/dogs/1

Modifier un chien :

curl -X PUT http://localhost:8080/api/v1/dogs/1 -H "Content-Type: application/json" -d "{\"name\":\"Rex\",\"breed\":\"Berger allemand\",\"age\":6}"

Supprimer un chien :

curl -X DELETE http://localhost:8080/api/v1/dogs/1

Tout fonctionne, l'API arrive bien à communiquer avec la base de données.
