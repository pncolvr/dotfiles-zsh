#!/usr/bin/env bash

# Backs up /home and the system essentials a fresh install can't bring back.
# See README.md. For a network destination use user@host:/path as BACKUP_ROOT.
BACKUP_ROOT="/mnt/Tardis"
DEST="$BACKUP_ROOT/$(hostname)"
SYSTEM_DEST="$DEST/system-essentials"

# What to skip in /home, as rsync filter rules ("- " exclude, "+ " include).
# The first rule that matches a path wins, so the "+" rules come first.
# Paths are relative to /home/: "/*/" means every user's home folder.
# A trailing "/" matches directories only. "**" matches any depth.
HOME_FILTERS=(
    # Kept even though rules below would match parts of them
    "+ /*/.local/share/vscode-profiles/***"
    "- /*/.config/Code/User/workspaceStorage/"
    "+ /*/.config/Code/User/***"
    "- /*/.config/Code/*"

    # Caches that browsers and Electron apps recreate on their own
    "- /*/.cache/"
    "- /*/.config/**/Cache/"
    "- /*/.config/**/Code Cache/"
    "- /*/.config/**/GPUCache/"
    "- /*/.config/**/CachedData/"
    "- /*/.config/**/DawnCache/"
    "- /*/.config/**/DawnGraphiteCache/"
    "- /*/.config/**/DawnWebGPUCache/"
    "- /*/.config/**/GrShaderCache/"
    "- /*/.config/**/ShaderCache/"
    "- /*/.config/**/Crashpad/"
    "- /*/.local/share/**/Cache/"
    "- /*/.local/share/**/Code Cache/"
    "- /*/.local/share/**/GPUCache/"
    "- /*/.local/share/**/CachedData/"
    "- /*/.local/share/**/ShaderCache/"
    "- /*/.local/share/**/Crashpad/"

    # Build output and dependencies in projects
    "- /*/Projects/**/bin/"
    "- /*/Projects/**/obj/"
    "- /*/Projects/**/target/"
    "- /*/Projects/**/.gradle/"
    "- node_modules/"
    "- .dart_tool/"
    "- __pycache__/"
    "- .venv/"

    # Apps: browsers sync themselves; the rest is app files or re-downloadable
    "- /*/.config/google-chrome/"
    "- /*/.config/vivaldi/"
    "- /*/.config/teams-for-linux/"
    "- /*/.config/Microsoft/"
    "- /*/.config/vesktop/"
    "- /*/.config/whatsdesk/"
    "- /*/.config/plasmaConfSaver/"
    "- /*/.config/discord/"
    "- /*/.config/nvm/"
    "- /*/.config/heroic/Partitions/"
    "- /*/.config/heroic/tools/"
    "- /*/.local/share/Steam/"
    "- /*/.local/share/Locally Uncensored/"
    "- /*/.local/share/com.purpledoubled.locally-uncensored/"
    "- /*/.local/share/lu-labs/"
    "- /*/.local/share/NuGet/"
    "- /*/.local/share/containers/"
    "- /*/.local/share/umu/"
    "- /*/.local/share/flatpak/"
    "- /*/.local/share/powershell/"
    "- /*/.local/share/fnm/"
    "- /*/.local/share/goverlay/"
    "- /*/ComfyUI/models/"
    "- /*/ComfyUI/venv/"

    # Toolchains, package caches and runtimes (reinstallable)
    "- /*/.local/pipx/"
    "- /*/.nuget/packages/"
    "- /*/.dotnet/"
    "- /*/.rustup/"
    "- /*/.cargo/registry/"
    "- /*/.cargo/git/"
    "- /*/go/"
    "- /*/.stack/"
    "- /*/.yarn/"
    "- /*/.npm/"
    "- /*/.nvm/"
    "- /*/.pyenv/"
    "- /*/.conda/"
    "- /*/.pub-cache/"
    "- /*/.ollama/"
    "- /*/.vscode/"
    "- /*/.azure-functions-core-tools/"
    "- /*/.electron-gyp/"
    "- /*/.u2net/"

    # Games, sandboxed apps and misc caches
    "- /*/.minecraft/"
    "- /*/.steam/"
    "- /*/.var/"
    "- /*/.surf/"
    "- /*/.nv/"
    "- /*/.debug/"
)

# Outside /home, worth keeping across a reinstall. Missing paths are skipped.
SYSTEM_PATHS=(
    /etc
    /opt
    /usr/local
    /root
    /srv
    /var/spool/cron
    # /var/lib/docker    # images and volumes; can be large
    /var/lib/libvirt
    # /var/lib/mysql     # database files; no MariaDB server installed right now
)

# -h: sizes/speeds in K/M/G
RSYNC_OUTPUT=(--human-readable --stats)

# Runs rsync with a progress bar: rsync_progress <label> <rsync args...>
# --no-i-r: scan the whole file list first, so the percentage only goes up.
# Time left is estimated from elapsed time vs percentage done, because rsync's
# own estimate is thrown off by unchanged files being skipped instantly.
function rsync_progress() {
    local label=$1 cols status
    shift
    cols=$(tput cols 2>/dev/null) || cols=80

    sudo rsync --no-i-r --info=progress2,flist2 "$@" 2>&1 | gawk -v cols="$cols" -v label="$label" '
        BEGIN { RS = "[\r\n]"; start = 0 }
        function endline() { if (live) { printf "\n"; live = 0 } }
        function hms(t) { return sprintf("%d:%02d:%02d", t / 3600, (t % 3600) / 60, t % 60) }
        /building file list/ || /^ *$/ { next }
        /^file has vanished: / || /some files vanished before they could be transferred/ { next }
        /^ *[0-9][0-9.,]* files\.\.\./ {
            printf "\r\033[K%s: scanning... %s files", label, $1; live = 1; fflush(); next
        }
        /^ *[0-9][0-9.,]*[A-Za-z]* +[0-9]+% / {
            now = systime(); if (!start) start = now
            pct = $2 + 0; el = now - start
            left = (pct > 0 && el >= 3) ? hms(el * (100 - pct) / pct) : "--:--:--"
            files = ""
            if (match($0, /to-chk=([0-9]+)\/([0-9]+)/, m))
                files = sprintf("  %*d/%d", length(m[2]), m[2] - m[1], m[2])
            info = sprintf(" %3d%%  %8s  %11s  left %s%s", pct, $1, $3, left, files)
            w = cols - length(label) - length(info) - 5; if (w < 10) w = 10
            fill = int(w * pct / 100); bar = ""
            for (i = 0; i < w; i++) bar = bar (i < fill ? "█" : "░")
            printf "\r\033[K%s: [%s]%s", label, bar, info; live = 1; fflush(); next
        }
        { endline(); print; fflush() }
        END { endline(); if (pct == 100) printf "%s: finished in %s\n", label, hms(systime() - start) }
    '
    status=${PIPESTATUS[0]}

    case $status in
        0) return 0;;
        20) echo "$label: interrupted" >&2; exit 130;;
        24) return 0;;  # files vanished during the copy (temp files etc.), harmless
        23) echo "$label: warning: some files could not be copied (rsync code 23), see errors above" >&2; return 0;;
        *) echo "$label: rsync failed (code $status)" >&2; return "$status";;
    esac
}

function check_backup_destination() {
    case "$BACKUP_ROOT" in
        *:*) return 0;;
    esac

    if ! mountpoint -q -- "$BACKUP_ROOT"; then
        printf "Backup destination is not mounted: %s\n" "$BACKUP_ROOT" >&2
        return 1
    fi
}

function mount_backup_destination() {
    case "$BACKUP_ROOT" in
        *:*) return 0;;
    esac

    mountpoint -q -- "$BACKUP_ROOT" && return 0

    echo "Mounting $BACKUP_ROOT"
    sudo mount -- "$BACKUP_ROOT" || return 1
}

# Unmounts and powers off the disk, even if it was mounted before the script ran.
function unmount_backup_destination() {
    case "$BACKUP_ROOT" in
        *:*) return 0;;
    esac
    mountpoint -q -- "$BACKUP_ROOT" || return 0

    # Write out everything still cached for the disk first, so the wait is
    # visible here instead of umount appearing to hang.
    echo "Flushing writes to $BACKUP_ROOT..."
    sudo sync -f -- "$BACKUP_ROOT"

    # Something may still be letting go of the disk (a file manager, the
    # indexer). Retry for a few seconds before giving up.
    local try device
    device=$(findmnt -no SOURCE -- "$BACKUP_ROOT")
    for try in {1..10}; do
        if sudo umount -- "$BACKUP_ROOT" 2>/dev/null; then
            echo "Unmounted $BACKUP_ROOT"
            # Spin down and cut power to the USB disk, like "Safely remove"
            if sudo udisksctl power-off -b "$device" 2>/dev/null; then
                echo "Powered off $device, safe to unplug"
            else
                echo "Could not power off $device, but it is unmounted and safe to unplug"
            fi
            return 0
        fi
        (( try == 1 )) && echo "$BACKUP_ROOT is busy, waiting..."
        sleep 1
    done

    echo "Could not unmount $BACKUP_ROOT, still in use by:" >&2
    sudo fuser -vm -- "$BACKUP_ROOT" >&2
    echo "Close those, then run: backup-eject" >&2
    echo "  (or by hand: sudo umount $BACKUP_ROOT && udisksctl power-off -b $device)" >&2
    return 1
}

function backup () {
    check_backup_destination || return 1
    echo "Backing up to $DEST"
    mkdir -p "$DEST"
    echo "backing up home"
    check_backup_destination || return 1
    local filters=() rule
    for rule in "${HOME_FILTERS[@]}"; do
        filters+=(--filter="$rule")
    done
    rsync_progress home -aAXxH --delete-excluded "${RSYNC_OUTPUT[@]}" \
        "${filters[@]}" /home/ "$DEST/home" || return 1

    echo "backing up system essentials"
    check_backup_destination || return 1
    mkdir -p "$SYSTEM_DEST/packages"
    pacman -Qqen > "$SYSTEM_DEST/packages/pkglist.txt"
    pacman -Qqem > "$SYSTEM_DEST/packages/aur.txt"
    echo "packages: $(wc -l < "$SYSTEM_DEST/packages/pkglist.txt") native, $(wc -l < "$SYSTEM_DEST/packages/aur.txt") AUR"

    local paths=() p
    for p in "${SYSTEM_PATHS[@]}"; do
        [[ -e $p ]] && paths+=("$p")
    done

    # -R keeps the full path: /etc -> $SYSTEM_DEST/files/etc
    check_backup_destination || return 1
    rsync_progress system -aAXxHR --delete "${RSYNC_OUTPUT[@]}" \
        "${paths[@]}" "$SYSTEM_DEST/files" || return 1
}

# Only /home is restored. System essentials are a reference for a fresh install.
function restore() {
    check_backup_destination || return 1
    rsync_progress home -aAXH "${RSYNC_OUTPUT[@]}" "$DEST/home/." /home || return 1

    cat <<EOF

System essentials are in $SYSTEM_DEST (not restored automatically):
  reinstall packages:  sudo pacman -S --needed - < $SYSTEM_DEST/packages/pkglist.txt
  AUR packages:        $SYSTEM_DEST/packages/aur.txt (install with your AUR helper)
  configs and data:    $SYSTEM_DEST/files/ (etc, opt, var/lib/libvirt, ...), copy what you need
EOF
}

# Mounts the disk and opens the backup in the file manager. Leaves it mounted.
# Run as your own user (not with sudo) so the file manager opens in your session.
function browse() {
    if (( EUID == 0 )); then
        echo "Run browse without sudo, so the file manager opens as your user" >&2
        return 1
    fi
    mount_backup_destination || return 1

    local dir=$DEST
    [[ -d $dir ]] || dir=$BACKUP_ROOT

    echo "Opening $dir"
    xdg-open "$dir" >/dev/null 2>&1 &
    disown

    echo "The disk stays mounted. When you're done, close the file manager and run:"
    echo "  backup-eject   (or: $0 eject)"
}

case $1 in
    backup|restore)
        trap unmount_backup_destination EXIT
        trap 'echo; echo "Interrupted" >&2; exit 130' INT TERM
        mount_backup_destination || exit 1
        "$1"
        ;;
    browse)
        browse
        ;;
    eject)
        if ! mountpoint -q -- "$BACKUP_ROOT"; then
            echo "$BACKUP_ROOT is not mounted"
            exit 0
        fi
        unmount_backup_destination
        ;;
    *)
        echo "Usage: $0 {backup|restore|browse|eject}" >&2
        exit 1
        ;;
esac

