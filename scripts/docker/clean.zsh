# Docker cleanup helpers. Add to ~/.zshrc:   source ~/Projects/spikes/systeminfo/cleanup/docker-clean.zsh
# Nothing here ever runs by itself; every command is something you type.

alias dkdf='docker system df'                              # how much space, what is reclaimable
alias dkdfv='docker system df -v | less'                   # per image/container/volume detail
alias dkvols='docker volume ls -qf dangling=true | grep -vE "^[0-9a-f]{64}$"'   # NAMED unused volumes (review these!)
alias dkact='docker volume ls -qf dangling=true | grep "^act-" | xargs -r docker volume rm'  # GitHub-Actions "act" caches

# Safe weekly cleanup: stopped containers, dangling images, build cache older than 30d,
# and ANONYMOUS unused volumes only (named volumes like bw-data, kyoo_db are never touched).
dkclean() {
  local major=${$(docker version -f '{{.Server.Version}}')%%.*}
  docker container prune -f
  docker image prune -f
  docker builder prune -f --filter until=720h
  if (( major >= 23 )); then
    docker volume prune -f
  else
    echo "Docker < 23: 'volume prune' would delete ALL unused volumes, skipping. Use dkvols and remove by hand."
  fi
  docker system df
}

# Deeper: also removes every image not used by a container (they get re-pulled/rebuilt when needed).
dkdeep() {
  dkclean
  docker image prune -a -f --filter until=2160h     # unused images older than 90 days
  docker builder prune -a -f                         # all build cache
  docker system df
}
