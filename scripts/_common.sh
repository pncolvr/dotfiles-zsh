#!/usr/bin/env bash

function get_env_file() {
    local path=$1
    local filename=$(basename "$path")
    filename="${filename%.*}"
    echo "$(dirname "$path")/$filename.env"
}

function check_dependencies() {
    printf "Checking dependencies... "
    missingDependencies=0
    for name in "$@"
    do
        if ! which "$name" 1>/dev/null 2>/dev/null; then
            printf "\n\t%s needs to be installed." "$name"
            missingDependencies=1;
        fi
    done
    if [ $missingDependencies -ne 1 ]; then
        printf "OK\n"
    else
        printf "\nInstall the above and rerun this script"
        exit 1
    fi
}

function print_success_message() {
    COLOR_GREEN="$(tput setaf 2)"
    print_message "$COLOR_GREEN" "$1"
}

function print_error_message() {
    COLOR_RED="$(tput setaf 1)"
    print_message "$COLOR_RED" "$1"
}

function print_message() {
    COLOR_REST="$(tput sgr0)"
    printf '%s%s%s\n' "$1" "$2" "$COLOR_REST"
}

function check_inside_git() {
    if ! git rev-parse --is-inside-work-tree 1>/dev/null 2>/dev/null; then
        echo "Must be inside git repo"
        exit 1
    fi
}

function log() {
    _internal_log 7 "$@"
}

function log_error() {
    _internal_log 4 "$@"
}

function _internal_log() {
    local priority
    local emitError
    priority=$1
    shift
    if [ -n "$1" ]; then
        IN="$1"
    else
        read IN
    fi
    case $priority in
        1|2|3|4) emitError="--stderr";;
        5|6|7) emitError="";;
    esac
    logger "$emitError" --priority "$priority" --tag $(basename "${BASH_SOURCE[0]:-0}") $IN
}
