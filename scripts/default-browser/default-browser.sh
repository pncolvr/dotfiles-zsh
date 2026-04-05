#!/usr/bin/env bash
# commented the browser env variable on /etc/environment
WORKSPACE=$(dirname "${BASH_SOURCE[0]:-0}")

source $HOME/.config/rofi/scripts/_common/utils.sh
env=$(get_temp_file_named "${BASH_SOURCE[0]:-0}")
source "$env"

function handle_akams () {
    local url="$*"
    if [[ "$url" == *"aka.ms"* ]]; then
        local redirect=$(curl -s -o /dev/null -w "%{url_effective}" -L "$url")
        if [[ -n "$redirect" ]]; then
            log "resolving to $redirect"
            main "$redirect"
        fi
    fi
}

function check_blocked_and_open () {
    local args="$*"
    if printf '%s' "$args" | grep -F -f "$WORKSPACE/blocklist" -q; then
        open_blocked_browser "$@"
        exit
    fi
} 

function open_blocked_browser () {
    local url="$*"
    local args=("$@")
    if ! printf '%s' "$url" | grep -F -q -- '--profile-directory'; then
        args+=(--profile-directory="$VIVALDI_PROFILE_DIRECTORY")
    fi
    move_to_workspace 9 "$url"
    vivaldi "${args[@]}" > /dev/null 2>&1 & disown
    exit
}

function check_webapp_and_open () {
    local url="$*"
    shift 1
    local args=("$@")
    if printf '%s' "$url" | grep -F -q -- 'qutebrowser-webapp'; then
        qutebrowser --desktop-file-name qutebrowser-webapp \
            --target window \
            -C ~/.config/qutebrowser/config.py \
            -B ~/.local/share/qutebrowser-webapp \
            "${args[@]}" > /dev/null 2>&1 & disown

        exit
    fi
}

function open_default_browser () {
    local url=$*
    move_to_workspace 1 "$url"
    qutebrowser "$@" & disown
    exit
}

function move_to_workspace () {
    local workspace=$1
    local url=$2
    if [[ ! "$url" == *--app* ]]; then # only change workspace if not webapp
        hyprctl dispatch workspace "$workspace" > /dev/null 2>&1
    fi
}

function check_steam_and_open () {
    local args="$*"
    if printf '%s' "$args" | grep -E '(store\.steampowered)' -q; then
        appid=$(echo "$args" | grep -oP '(?<=/app/)[0-9]+')
        if [ -n "$appid" ]; then
            hyprctl dispatch workspace 5 > /dev/null 2>&1
            steam "steam://store/$appid" & disown
            exit
        fi
    fi
}

function main() {
    check_steam_and_open "$@"
    check_webapp_and_open "$@"
    check_blocked_and_open "$@"
    open_default_browser "$@"
    exit
}

log "opening $*"
handle_akams "$@"
main "$@"
