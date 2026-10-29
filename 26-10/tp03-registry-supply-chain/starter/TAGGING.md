Politique de tags Shop SAS

Tags utilisés pour une image :

1.4.2          version semver complète, immuable
1.4            dernière version 1.4.x, déplacé à chaque patch
1              dernière version 1.x.y, déplacé à chaque mineure
sha-8148417    commit git qui a produit l'image, immuable
build-123      numéro de build CI, pour les images de test, supprimé par retention.sh

Tags immuables : X.Y.Z et sha-<commit>. Une fois poussés ils ne sont jamais réécrits, une correction donne un nouveau numéro de version. Les tags 1.4 et 1 sont des alias pratiques pour les environnements de dev, jamais pour la prod.

latest est interdit en prod parce qu'il ne dit pas quelle version tourne, qu'il change sans prévenir (c'est l'incident du vendredi soir), que deux noeuds peuvent avoir deux images différentes sous le même nom, et qu'on ne peut pas revenir en arrière sur "latest d'avant".

En prod on référence l'image par digest, qui est l'empreinte du manifeste et ne peut pas changer :

services:
  api:
    image: registry.local:5000/shopapi:1.4.2@sha256:2053427abb27a127dde27456bb1881a34172816491468c8806a1e3f895e5d78f

Avec tag + digest, docker utilise le digest, le tag reste juste lisible pour les humains. C'est aussi ce digest qui est signé par cosign.

Retaguer sans pull (crane copie juste le manifeste côté registre) :

docker run --rm --network shop-registry_default -v "$(pwd)/registry/certs/ca.crt:/ca.crt:ro" -e SSL_CERT_FILE=/ca.crt --entrypoint sh gcr.io/go-containerregistry/crane:debug -c "crane auth login registry.local:5000 -u ci -p ci-push-2024 && crane tag registry.local:5000/shopapi:1.4.2 1.4 && crane tag registry.local:5000/shopapi:1.4.2 sha-8148417"

crane digest registry.local:5000/shopapi:1.4
sha256:2053427abb27a127dde27456bb1881a34172816491468c8806a1e3f895e5d78f
crane digest registry.local:5000/shopapi:1.4.2
sha256:2053427abb27a127dde27456bb1881a34172816491468c8806a1e3f895e5d78f

Les trois tags pointent sur le même digest.
