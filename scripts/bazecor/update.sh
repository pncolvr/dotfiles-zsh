#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

url=$(curl -s $N8N_BAZECOR_UPDATE_URL | jq -r '.url')

if [ -z "$url" ]; then
    echo "No URL found"
    exit 1
fi


filename=$(basename "$url")

if [ -f ~/Dygma/"$filename" ]; then
    echo "$filename already exists"
    exit 1
fi

echo "Downloading $filename"
wget -O ~/Dygma/"$filename" "$url"

echo "Updating Dygma"
cp -rf ~/Dygma/"$filename" ~/Dygma/Bazecor.AppImage
chmod +x ~/Dygma/Bazecor.AppImage


