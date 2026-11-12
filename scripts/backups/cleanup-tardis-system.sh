#!/usr/bin/env bash
# One-off: delete the old full system backup from Tardis, with progress.
# Leaves home/ and system-essentials/ alone.
# Left because it seems useful for other workflows
BACKUP_ROOT=/mnt/Tardis
TARGET="$BACKUP_ROOT/$(hostname)/system"

step() { printf '\n==> %s\n' "$*"; }

step "Asking for sudo password up front"
sudo -v || exit 1

step "Checking that $BACKUP_ROOT is mounted"
if ! mountpoint -q -- "$BACKUP_ROOT"; then
    echo "Not mounted, mounting it"
    sudo mount -- "$BACKUP_ROOT" || { echo "Mount failed" >&2; exit 1; }
fi
findmnt -no SOURCE,TARGET -- "$BACKUP_ROOT"

step "Checking what will be deleted"
if [[ ! -d $TARGET ]]; then
    echo "$TARGET does not exist, nothing to do"
    exit 0
fi
echo "Will delete:  $TARGET"
echo "Will keep:"
for d in "$BACKUP_ROOT/$(hostname)"/*; do
    [[ $d != "$TARGET" ]] && echo "              $d"
done

read -rp "Continue? [y/N] " answer
[[ $answer == [yY] ]] || { echo "Cancelled"; exit 0; }

step "Counting files (no deletion yet)"
total=$(sudo find "$TARGET" | pv -l -N counting | wc -l)
echo "$total entries to delete"

step "Deleting with 8 parallel rm processes"
{
    sudo find "$TARGET" -mindepth 2 -maxdepth 2 -print0 | sudo xargs -0 -P8 rm -rfv
    sudo rm -rfv "$TARGET"
} | pv -l -s "$total" -N deleting > /dev/null

step "Checking result"
if [[ -e $TARGET ]]; then
    left=$(sudo find "$TARGET" | wc -l)
    echo "Not everything was deleted: $left entries left in $TARGET" >&2
    echo "Run this script again, or look at the errors above" >&2
    exit 1
fi
echo "Deleted $TARGET"
df -h -- "$BACKUP_ROOT" | tail -1 | awk '{print "Disk now: " $3 " used, " $4 " free"}'

step "Done. To unmount and power off the disk:"
echo "sudo umount $BACKUP_ROOT && udisksctl power-off -b $(findmnt -no SOURCE -- "$BACKUP_ROOT")"
