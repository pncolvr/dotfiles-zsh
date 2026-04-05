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