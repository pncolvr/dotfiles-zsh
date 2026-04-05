#!/usr/bin/env bash

if [ $# -lt 1 ];then
    echo "Usage: '$(basename "${BASH_SOURCE[0]:-0}")' [-t] FILES"
    exit 1
fi

useYad=true

while getopts ":t" opt; do
    case $opt in
        t)
            useYad=false
            ;;
        \?)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

shift $((OPTIND -1))

if [ "$useYad" = true ]; then
     options=$(
        yad \
        --form --separator="," \
        --title="Archive name?" \
        --width=200 --height=50 \
        --field="" \
        --field=":CB" \
        --button="Go"!gtk-ok \
        "" 7z!tar.gz!zip!
    )   
    archiveName=$(echo "$options" | cut -d',' -f1)
    extension=$(echo "$options" | cut -d',' -f2)
else
    read -r -p "Enter the name of the archive: " archiveName < /dev/tty
    read -r -p "Enter desired extension (7z, tar.gz, zip): " extension < /dev/tty
fi

if [ -z "$archiveName" ]; then
    # eg: 2024-07-13_14-15-20
    archiveName=$(date +%Y-%m-%d_%H-%M-%S)
fi

case $extension in
    7z)
        7z a -r "$archiveName.7z" "$@"
        ;;
    zip)
        zip -r "$archiveName.zip" "$@"
        ;;
    tar.gz)
        tar -czvf "$archiveName.tar.gz" "$@"
        ;;
    *)
        echo "Invalid extension: $extension"
        exit 1
        ;;
esac