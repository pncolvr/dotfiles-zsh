#!/usr/bin/env bash

if [ $# -lt 1 ];then
  echo "Usage: '$(basename "${BASH_SOURCE[0]:-0}")' FILES"
  exit 1
fi

for arg in "$@"
do
    if [ -f "$arg" ] ; then
        curDir=$(pwd)
        fullFilePath=$(realpath "$arg")
        fileDir=${fullFilePath%/*}
        
        filename=$(basename -- "$fullFilePath")
        filenameWithoutExtension="${filename%.*}"
        extractionDir="$fileDir/$filenameWithoutExtension"

        mkdir -p "$extractionDir"
        cd "$extractionDir" || exit

        case $arg in
            *.tar.bz2)  tar xjf "$fullFilePath"      ;;
            *.tar.gz)   tar xzf "$fullFilePath"      ;;
            *.bz2)      bunzip2 "$fullFilePath"      ;;
            *.gz)       gunzip "$fullFilePath"       ;;
            *.tar)      tar xf "$fullFilePath"       ;;
            *.tbz2)     tar xjf "$fullFilePath"      ;;
            *.tgz)      tar xzf "$fullFilePath"      ;;
            *.zip)      unzip "$fullFilePath"        ;;
            *.Z)        uncompress "$fullFilePath"   ;;
            *.rar)      rar x "$fullFilePath"        ;;
            *.jar)      jar -xvf "$fullFilePath"     ;;
            *.7z)       7za x "$fullFilePath"        ;;  
            *)          echo "'$fullFilePath' cannot be extracted via '$(basename "${BASH_SOURCE[0]:-0}")'" && exit ;;
        esac
        trash "$fullFilePath"
        cd "$curDir" || exit
    else
        echo "'$arg' is not a valid file" && exit
    fi
done
