#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
check_dependencies git jq

env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

u=$N8N_BASE_URL
k=$N8N_KEY
d=$OUTPUT_FOLDER
e=$DELETE_EXISTING

usage() {
   echo
   echo "Syntax: "${BASH_SOURCE[0]:-0}" -u <string> -k <string> -d <string> [-e true|false]"
   echo "options:"
   echo "   -u|--url            n8n base endpoint"
   echo "   -k|--key            n8n API key"
   echo "   -d|--destination    save folder"
   echo "   -e|--delete         delete existing files"
   echo "   -h|--help           Print this usage message"
   echo
}

die() {
    usage
    exit 1
}

while [ "$#" -gt 0 ]
    do case $1 in
        -u|--url) u="$2";;
        -k|--key) k="$2";;
        -d|--destination) d="$2";;
        -e|--delete) e="$2";;
        -h|--help) usage; exit 0;;
        *) die;
    esac
    shift
    shift
done

baseEndpoint="$u"
key="$k"
saveDirectory="$d"
deleteExisting="$e"

[ -z "$baseEndpoint" ] && die
[ -z "$key" ] && die
[ -z "$saveDirectory" ] && die
[ -z "$deleteExisting" ] && deleteExisting=false

mkdir -p "$saveDirectory"
cd "$saveDirectory" || exit 

#TODO iterate pages
workflowsJson=$(curl -s -X 'GET' "$baseEndpoint/api/v1/workflows" -H 'accept: application/json' -H "X-N8N-API-KEY: $key") 

[ -z "$workflowsJson" ] && echo "not able to get workflows json" && exit

check_inside_git

git pull

if [ "$deleteExisting" = true ]; then
    rm -rf "$saveDirectory"
    mkdir -p "$saveDirectory"
    cd "$saveDirectory" || exit 
fi

printf "%s" "$workflowsJson" | jq -rc '.data[]' | while IFS='' read -r workflow;do
    name=$(printf "%s" "$workflow" | jq -r .name)
    printf "%s" "$workflow" > "$name.json"
done

currentTime=$(date +"%Y-%m-%dT%H%M%S")
git add --all
git commit -m "[n8n] backup at $currentTime"
git push