#!/usr/bin/env bash

# Initialize a flag for skipping checks
skipChecks=false

# Parse script parameters
while getopts ":y" opt; do
  case ${opt} in
    y )
      skipChecks=true
      ;;
    \? )
      echo "Usage: cmd [-y]"
      exit 1
      ;;
  esac
done

doGitPull() {
    repo="$1"
    prevDir=$(pwd)
    cd "$repo" || exit
    echo -n "$repo: "
    git pull || exit
    cd "$prevDir" || exit
}

makeExecutable() {
    file="$1"
    echo "File '$file' is now executable."
    chmod +x "$file"
}

handleUserManualOrAutomaticChoice() {
    file="$1"
    if [ "$skipChecks" = false ]; then
        read -r -p "File '$file' is not executable. Do you want to make it executable? [Y/n] " answer < /dev/tty
        answer=${answer:-Y}
        if [[ $answer =~ ^[Yy]$ ]]; then
            makeExecutable "$file"
        fi
    else
        makeExecutable "$file"
    fi
}

checkExecutable() {
    repo="$1"
    while read -r file
    do
        if [[ ! -x "$file" ]]; then
            handleUserManualOrAutomaticChoice "$file"
        fi
    done < <(find "$repo" -type f -name "*.ps1" -o -name "*.sh")
}

echo -n "$HOME: "
/usr/bin/git --git-dir="$HOME"/.cfg/ --work-tree="$HOME" pull || exit

repos=("$HOME/Projects/scripts" "$HOME/Projects/kb")
for repo in "${repos[@]}"; do
    doGitPull "$repo"
    checkExecutable "$repo"
done

doGitPull "$HOME/Pictures"