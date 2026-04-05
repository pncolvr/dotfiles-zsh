#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

if [ -z "$1" ]; then
    echo "Usage: "${BASH_SOURCE[0]:-0}" <github personal access token>"
    exit 1
fi

file=~/.nuget/NuGet/NuGet.Config
filepath=$(realpath "$file")

if [ ! -f "$filepath" ]; then
    echo "File not found: $file"
    exit 1
fi

dotnet nuget update source github --store-password-in-clear-text --username "$GITHUB_USERNAME" --password "$1"
