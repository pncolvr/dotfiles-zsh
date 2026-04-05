#!/bin/bash
# source: https://www.reddit.com/r/linuxmint/comments/pyqc10/can_i_use_grsync_or_rsync_to_do_the_same_as
# Backup using rsync to a different disk (/media/Backups):
# Home
# sudo rsync -aAXxH /home --delete-before /media/Backups/Rsync-Home
# System
# sudo rsync -aAXxH / --exclude={/cdrom,/dev,/home,/media,/mnt,/proc,/run,/sys,/tmp} /media/Backups/Rsync-System
# Restore from /media/Backups:
# Home
# sudo rsync -aAXv /media/mint/Backups/Rsync-Home/. /home
# System
# sudo rsync -aAXv /media/Backups/Rsync-System/. --exclude={/cdrom,/dev,/home,/media,/mnt,/proc,/run,/sys,/tmp} /
# If you want to backup/recover to/from a network drive just add the network address in the form of user@n.n.n.n: in front of the directory
source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

DEST="$DEST/$(hostname)"

function backup () {
    echo "Backing up to $DEST"
    mkdir -p "$DEST"
    echo "backing up home"
    sudo rsync -aAXxH --delete-before --delete-excluded --info=progress2 --stats \
        --exclude='.cache' \
        --exclude='.local/share/Steam' \
        --exclude='.nuget/packages' \
        --exclude='.ollama' \
        --exclude='.dotnet' \
        --exclude='.vscode' \
        --exclude='.stack' \
        --exclude='go' \
        --exclude='.yarn' \
        --exclude='.minecraft' \
        --exclude='.pub-cache' \
        --exclude='.var' \
        --exclude='.surf' \
        --exclude='.config/vivaldi' \
        --exclude='.config/Code' \
        --exclude='.config/heroic' \
        --exclude='.config/vesktop' \
        --exclude='.config/plasmaConfSaver' \
        --exclude='.config/teams-for-linux' \
        --exclude='.config/whatsdesk' \
        --exclude='.config/Microsoft' \
        --exclude='.config/google-chrome' \
        /home/ "$DEST/home"

    echo "backing up system"
    sudo rsync -aAXxH --delete-before --delete-excluded --info=progress2 --stats \
        --exclude={/cdrom,/dev,/home,/media,/mnt,/proc,/run,/sys,/tmp,/swapfile} \
        / "$DEST/system"
}

function restore() {
    sudo rsync -aAXv  --info=progress2 --stats "$DEST/home/." /home
    sudo rsync -aAXHv --info=progress2 --stats \
        --exclude={/cdrom,/dev,/home,/media,/mnt,/proc,/run,/sys,/tmp,/swapfile} \
        "$DEST/system/." /
}

case $1 in 
    backup) backup;;
    restore) restore;;
esac

