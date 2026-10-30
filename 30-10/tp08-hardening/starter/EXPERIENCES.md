# Expériences

| Mesure | Expérience | Résultat |
|--------|-----------|----------|
| `--read-only` | `docker run --rm --read-only alpine touch /x` puis `docker run --rm --read-only --tmpfs /tmp alpine touch /tmp/x` | `touch: /x: Read-only file system`, puis `/tmp/x` créé : seul le tmpfs est inscriptible |
| `--cap-drop ALL` (ping) | `docker run --rm --cap-drop ALL alpine ping -c1 1.1.1.1` | Le ping marche quand même : Docker règle `net.ipv4.ping_group_range` à `0 2147483647` et ping utilise une socket ICMP non privilégiée. Avec `--sysctl net.ipv4.ping_group_range="1 0"` : `ping: permission denied (are you root?)`, et ça remarche avec `--cap-add NET_RAW` |
| `--cap-drop ALL` (chown) | `docker run --rm --cap-drop ALL alpine chown nobody /etc/hostname` | `Operation not permitted`, OK avec `--cap-add CHOWN` |
| `--cap-drop ALL` (apk) | `docker run --rm --cap-drop ALL alpine apk add curl` puis `apk add dbus` | curl s'installe (fichiers de root écrits par root, pas besoin de capability). dbus échoue : `Failed to set ownership ... Operation not permitted`, il faut `CHOWN` (et `FOWNER`/`DAC_OVERRIDE` pour les fichiers d'autres utilisateurs). En prod on n'installe rien au runtime, donc on ne rajoute rien |
| `--security-opt no-new-privileges` | `docker run --rm alpine ls -l /bin/busybox` : pas setuid. Image de test avec une copie setuid de `id` (`chmod u+s /opt/suid/id`), lancée en `--user 1000` | Sans l'option : `uid=1000 gid=0(root) euid=0(root)`, le setuid donne root. Avec : `uid=1000 gid=0(root)`, plus d'élévation |
| `--pids-limit 50` | `docker run --rm --pids-limit 50 alpine sh -c 'for i in $(seq 100); do sleep 60 & done; sleep 1; ps \| wc -l'` | `sh: can't fork: Resource temporarily unavailable`. Sans limite : 104 processus |
| `--memory 32m` | `docker run --memory 32m python:3.12.16-slim-bookworm python -c "x='a'*100_000_000"` | exit 137, `docker inspect` : `OOMKilled=true` |
| `--user 1000` | `docker run --rm --user 1000 alpine id` puis écriture dans un volume rempli par root | `uid=1000 gid=0(root)`. Le volume contient `fichier-root` (uid 0) et `touch /data/x` donne `Permission denied` : il faut que le dossier du volume appartienne à l'uid du conteneur (`chown` dans l'image ou au premier lancement) |
| seccomp | `docker run --rm alpine unshare --user id` puis avec `--security-opt seccomp=unconfined` | `unshare(0x10000000): Operation not permitted` avec le profil par défaut, `uid=65534(nobody)` sans seccomp. Le profil par défaut est une liste blanche qui bloque environ 44 appels système sur plus de 300 (par exemple unshare, mount, reboot, kexec_load) |
