#!/usr/bin/env bash
# audit.sh [PROJET] : audit de durcissement des conteneurs en cours d'exécution
# (tous, ou seulement ceux du projet compose donné). Code retour 1 s'il y a au moins un écart.
set -uo pipefail

filter=()
[ -n "${1:-}" ] && filter=(--filter "label=com.docker.compose.project=$1")
ids=$(docker ps -q "${filter[@]}")
[ -z "$ids" ] && { echo "aucun conteneur en cours d'exécution"; exit 0; }

total=0
printf '%-22s %-10s %-5s %-14s %-14s %-3s %-8s %-5s %-4s %-6s %s\n' \
  CONTENEUR USER PRIV CAP_DROP CAP_ADD RO MEMOIRE PIDS NNP SOCKET ECARTS
for id in $ids; do
  IFS='|' read -r name user priv capdrop capadd ro mem pids secopt mounts < <(docker inspect "$id" --format \
    '{{.Name}}|{{.Config.User}}|{{.HostConfig.Privileged}}|{{join .HostConfig.CapDrop ","}}|{{join .HostConfig.CapAdd ","}}|{{.HostConfig.ReadonlyRootfs}}|{{.HostConfig.Memory}}|{{if .HostConfig.PidsLimit}}{{.HostConfig.PidsLimit}}{{else}}0{{end}}|{{join .HostConfig.SecurityOpt ","}}|{{range .Mounts}}{{.Source}} {{end}}')
  name=${name#/}
  ecarts=()
  case "${user%%:*}" in ""|root|0) ecarts+=(root) ;; esac
  [ "$priv" = "true" ] && ecarts+=(privileged)
  [[ ",$capdrop," == *",ALL,"* ]] || ecarts+=(cap_drop)
  [ "$ro" = "true" ] || ecarts+=(rootfs_rw)
  [ "$mem" -gt 0 ] || ecarts+=(sans_limite_memoire)
  [ "$pids" -gt 0 ] || ecarts+=(sans_pids_limit)
  nnp=oui
  if [[ "$secopt" != *no-new-privileges* ]]; then nnp=non; ecarts+=(sans_no_new_privileges); fi
  sock=non
  if [[ "$mounts" == *docker.sock* ]]; then sock=oui; ecarts+=(socket_docker); fi
  [ "$mem" -gt 0 ] && memh="$((mem / 1024 / 1024))M" || memh=aucune
  total=$((total + ${#ecarts[@]}))
  printf '%-22s %-10s %-5s %-14s %-14s %-3s %-8s %-5s %-4s %-6s %s\n' \
    "$name" "${user:-root}" "$priv" "${capdrop:--}" "${capadd:--}" "$( [ "$ro" = true ] && echo oui || echo non)" \
    "$memh" "$pids" "$nnp" "$sock" "${ecarts[*]:-OK}"
done
echo
echo "Écarts : $total"
[ "$total" -eq 0 ]
