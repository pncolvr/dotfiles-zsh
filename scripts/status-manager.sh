#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

function check_processes() {
    local found=0
    
    for pattern in "${WORKING_PROCESSES[@]}"; do
        if pgrep -u "$USER" -x "$pattern" > /dev/null; then
            found=1
            break
        fi
    done

    if [[ $found -eq 1 ]]; then
        return 0
    else
        return 1
    fi
}

function has_open_files_in_folder() {
    lsof -u "$USER" 2>/dev/null | grep -q "$WORK_BASE_DIRECTORY"
}

function get_state() {
    local state=""

    if [[ -f "$STATE_FILE" ]]; then
        state=$(cat "$STATE_FILE")
    else
        state=$(calc_state_from_heuristics)
    fi

    log_state "$state"
    echo -n "$state"
}

function calc_state_from_heuristics() {
    local state
    if check_processes || has_open_files_in_folder; then
        state="$WORKING_STATE_NAME"
    else
        state="$NOTWORKING_STATE_NAME"
    fi
    echo -n "$state"
}

function log_state() {
    local state="$1"
    local timestamp=$(date +%s)
    local last_date last_state
    if [[ -f "$LOG_FILE" ]]; then
        IFS=';' read -r last_date last_state < <(tail -n 1 "$LOG_FILE")
        if [[ "$last_state" == "$state" ]]; then
            return
        fi
    fi
    echo "$timestamp;$state" >> "$LOG_FILE"
}

function set_state() {
    local desired_state="$1"

    if [[ "$desired_state" != "$WORKING_STATE_NAME" && "$desired_state" != "$NOTWORKING_STATE_NAME" ]]; then
        echo "Error: Invalid state provided. Must be '$WORKING_STATE_NAME' or '$NOTWORKING_STATE_NAME'."
        return 1
    fi

    echo "$desired_state" > "$STATE_FILE"
}

function clear_state() {
    if [[ -f "$STATE_FILE" ]]; then
        rm -f "$STATE_FILE"
    fi
}

function toggle() {
    if [[ "$(get_state)" == "$WORKING_STATE_NAME" ]]; then
        set_state "$NOTWORKING_STATE_NAME"
    else 
        set_state "$WORKING_STATE_NAME"
    fi
}

function get_source() {
    if [[ -f "$STATE_FILE" ]]; then
        echo manual
    else
        echo automatic
    fi
}

function usage () {
    echo "Usage: $0 [command] [argument]"
    echo ""
    echo "Commands:"
    echo "  $0 --check               Check the current state."
    echo "  $0 --set [$WORKING_STATE_NAME|$NOTWORKING_STATE_NAME] Manually set the state."
    echo "  $0 --toggle              Toggles the state, considered manually set."
    echo "  $0 --source              Returns either manual or automatic."
    echo "  $0 --clear               Clear the manual state override."
    echo "  $0 --help                Show this usage message."
}

if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

case "$1" in
    --check)
        get_state
        ;;
    --set)
        if [[ $# -ne 2 ]]; then
            echo "Error: --set requires a state ($WORKING_STATE_NAME or $NOTWORKING_STATE_NAME)."
            exit 1
        fi
        set_state "$2"
        ;;
    --toggle)
        toggle
        ;;
    --source)
        get_source
        ;;
    --clear)
        clear_state
        ;;
    --help)
        usage
        ;;
    *)
        usage
        exit 1
esac