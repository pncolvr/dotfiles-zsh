#!/usr/bin/env bash
# commented the browser env variable on /etc/environment
WORKSPACE=$(dirname "${BASH_SOURCE[0]:-0}")

source $HOME/.config/rofi/scripts/_common/utils.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")

source "$env"

function handle_ms_hiding_links () {
    local url="$*"
    local new
    if [[ "$url" == *"aka.ms"* ]]; then
        new=$(curl -s -o /dev/null -w "%{url_effective}" -L "$url")
    elif [[ "$url" == *"statics.teams.cdn.office.net"* ]] ;then
        new=$(printf '%b\n' "$(echo "$url" | sed -n 's/.*[?&]url=\([^&]*\).*/\1/p' | sed 's/%/\\x/g')")
    fi

    if [[ -n "$new" ]]; then
        log "resolving to $new"
        main "$new"
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
        log "adding default profile directory $VIVALDI_PROFILE_DIRECTORY"
        args+=(--profile-directory="$VIVALDI_PROFILE_DIRECTORY")
    fi
    move_to_workspace 9 "$url"
    vivaldi "${args[@]}" > /dev/null 2>&1 & disown
    exit
}

function check_webapp_and_open () {
    local option="$1"
    shift 1
    local args=("$@")
    if matches_pattern "$option" "${WEB_APPS[@]}"; then
        open_qutebrowser_with_profile "$option" "${args[@]}"
    elif matches_pattern "$option" "${LOCALHOST_WORK[@]}"; then
        open_blocked_browser "$option" "${args[@]}"
    elif matches_pattern "$option" "${LOCALHOST_PERSONAL[@]}"; then
        open_qutebrowser_with_profile "$LOCALHOST_QB_PROFILE" "$option" "${args[@]}"
    fi
}

function matches_pattern() {
    local value="$1"
    shift
    for pattern in "$@"; do
        [[ $value == $pattern ]] && return 0
    done
    return 1
}

function open_qutebrowser_with_profile () {
    local profile="$1"
    shift 1
    local args=("$@")
    qutebrowser --desktop-file-name "$profile" \
                --target window \
                -C ~/.config/qutebrowser/config.py \
                -B ~/.local/share/"$profile" \
                "${args[@]}" > /dev/null 2>&1 & disown
    exit
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
    if pgrep -u "$USER" -x "steam" > /dev/null && printf '%s' "$args" | grep -E '(store\.steampowered)' -q; then
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
handle_ms_hiding_links "$@"
main "$@"
