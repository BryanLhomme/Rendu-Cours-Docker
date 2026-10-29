TP02 Rapport


1. Prouver la fuite

docker build --build-arg PIP_INDEX_URL=https://svc-ci:Tr3sS3cret@pypi.internal.example.com/simple -t worker:leak .

Le build échoue car pypi.internal.example.com n'existe pas. Pour avoir une image, je refais le build avec les mêmes identifiants sur pypi.org (il ignore l'authentification) :

docker build --build-arg PIP_INDEX_URL=https://svc-ci:Tr3sS3cret@pypi.org/simple -t worker:leak .

docker history --no-trunc worker:leak | grep -i secret

RUN |1 PIP_INDEX_URL=https://svc-ci:Tr3sS3cret@pypi.org/simple /bin/sh -c pip install -r requirements-dev.txt

Endroits où le secret est visible :

- docker history : la valeur des ARG utilisés par un RUN est écrite dans l'historique de l'image.
- docker inspect / config de l'image : docker image save worker:leak puis grep sur le tar retrouve svc-ci:Tr3sS3cret dans le json de config.
- dans une couche : COPY . . copie pip.conf.example dans /app, docker run --rm worker:leak cat /app/pip.conf.example affiche index-url = https://svc-ci:Tr3sS3cret@pypi.internal.example.com/simple.
- l'attestation de provenance (--provenance=mode=max) enregistre aussi les build-args.

Même si on supprime le fichier dans une couche suivante, il reste dans la couche d'avant.

2. Secret mount

Fichier pip.conf local (dans .gitignore et .dockerignore) :

[global]
index-url = https://pypi.org/simple

docker build --secret id=pipconf,src=pip.conf -t worker:1.0 .

Vérification :

docker history --no-trunc worker:1.0 | grep -i -c -E 'secret|pypi|pip.conf'
0
docker run --rm worker:1.0 cat /etc/pip.conf
cat: /etc/pip.conf: No such file or directory

Le secret est monté seulement pendant le RUN, il n'est écrit dans aucune couche ni dans l'historique.

Alternatives :

- --mount=type=ssh avec docker build --ssh default : pour pip install git+ssh://... sur un dépôt privé, la clé reste sur l'agent ssh de la machine.
- --secret id=TOKEN,env=TOKEN : le secret vient d'une variable d'environnement de la CI au lieu d'un fichier, et RUN --mount=type=secret,id=TOKEN,env=TOKEN le remet en variable seulement pour la commande.

3. Cache mount

docker build --secret id=pipconf,src=pip.conf -t worker:1.0 .
docker builder prune -f
echo "requests==2.32.3" >> requirements.txt
docker build --secret id=pipconf,src=pip.conf -t worker:1.0 .

Mesures (build complet) :

premier build sans aucun cache                    16.3 s
rebuild sans changement                           2.1 s
prune -f + ajout de requests                      13.7 s

Mesures de l'étape pip install seule (docker build --progress=plain), après ajout de requests dans requirements.txt :

cache mount chaud, sans prune                     3.8 s (pip affiche "Using cached ...")
après docker builder prune -f                     7.4 s (tous les paquets retéléchargés)
--no-cache                                        7.4 s (6 "Downloading", aucun "Using cached")

Le cache de couches garde le résultat d'une instruction entière : si requirements.txt change, la couche pip install est jetée et tout est réinstallé. Le cache mount est un dossier (/root/.cache/pip) gardé par BuildKit entre les builds et jamais mis dans l'image : pip refait l'install mais reprend les paquets déjà téléchargés, ici le temps de l'étape est divisé par 2.

Sur ma version de Docker (29.1.3), docker builder prune -f supprime aussi le cache mount quand il n'est pas en cours d'utilisation : docker buildx du --verbose ne montre plus de ligne "cached mount /root/.cache/pip" après le prune, et le build suivant retélécharge tout.

Avec --no-cache, le cache de couches est ignoré et le cache mount aussi : pip retélécharge tous les paquets.

4. Multi-architecture

docker run -d --name registry-tp02 -p 5000:5000 registry:2
docker buildx create --name shop --driver docker-container --driver-opt network=host --use
docker buildx inspect --bootstrap
docker buildx build --platform linux/amd64,linux/arm64 --secret id=pipconf,src=pip.conf -t localhost:5000/shop-worker:1.0 --push .
docker buildx imagetools inspect localhost:5000/shop-worker:1.0

network=host sert à ce que le builder (qui tourne dans un conteneur) puisse joindre localhost:5000.

Temps du build multi-arch : 1 min 56 s (contre 16 s pour amd64 seul).

Résultat :

MediaType: application/vnd.oci.image.index.v1+json
Digest:    sha256:0e0ca3d4244e4f50e62969488281a311e09041d99a251c5d25aa2a0cc9681c83
linux/amd64      sha256:42c908ad56802b9e3f3e94dea054ae22f4bc694c3a289a9f3873bb0f9217ce5d
linux/arm64      sha256:fb06331423550e6b890248bf835c6cf89a518a26d72c4b8fe2ad332adb231d83
unknown/unknown  attestation-manifest de amd64
unknown/unknown  attestation-manifest de arm64

--push ou -o est obligatoire parce que le store d'images classique de docker ne sait garder qu'une image par tag pour une plateforme, il ne peut pas charger un index avec plusieurs architectures. Le résultat doit donc partir dans un registre ou dans un fichier OCI.

Le manifest list (index OCI) contient la liste des manifestes de chaque plateforme avec leur digest, leur os/architecture, et les manifestes d'attestation. Au pull, docker prend le manifeste qui correspond à sa machine.

TARGETARCH est rempli par BuildKit pour chaque plateforme. Je l'utilise dans l'id du cache mount (id=pip-${TARGETARCH}) pour que les wheels amd64 et arm64 ne soient pas mélangées dans le même cache.

Le build arm64 sur une machine amd64 passe par QEMU qui émule chaque instruction arm64, d'où la lenteur. L'alternative est d'ajouter au builder un noeud arm64 natif (docker buildx create --append --name shop --platform linux/arm64 ssh://user@noeud-arm64) pour que chaque plateforme soit construite sur sa propre machine, ou d'utiliser un builder distant (Docker Build Cloud).

5. Cache distant

docker buildx build --platform linux/amd64 --cache-to type=registry,ref=localhost:5000/cache:worker,mode=max --cache-from type=registry,ref=localhost:5000/cache:worker --secret id=pipconf,src=pip.conf -t localhost:5000/shop-worker:1.0-amd64 --push .
docker buildx prune -af
docker buildx build ... (même commande)

Après le prune, 8 étapes sont CACHED grâce au cache récupéré dans le registre, comme le ferait un autre runner de CI.

En CI on peut utiliser type=gha (cache GitHub Actions) ou type=s3 (bucket S3).

mode=min exporte seulement les couches de l'image finale. mode=max exporte aussi les couches des étapes intermédiaires (builder, test), le cache est plus gros mais tout le multi-stage est réutilisable.

6. docker buildx bake

Fichier ../docker-bake.hcl : groupe default (api du TP01 + worker), cible abstraite _common (plateformes, labels), variables VERSION, GIT_SHA, REGISTRY, cible worker-test.

cd ..
docker buildx bake --print
VERSION=1.0 GIT_SHA=8148417 docker buildx bake worker-test

All checks passed!
2 passed in 0.11s

VERSION=1.0 GIT_SHA=8148417 docker buildx bake --set *.platform=linux/amd64 --load

localhost:5000/shopapi:1.0       211MB
localhost:5000/shop-worker:1.0   218MB
