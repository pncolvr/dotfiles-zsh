#!/usr/bin/env bash

# exit on error
set -e

find . -name '*.csproj' | while read -r csproj; do
    if grep -qi '<IsPackable>\s*false\s*</IsPackable>' "$csproj"; then
        echo "Skipping $csproj (IsPackable=false)"
        continue
    fi

    project_dir=$(dirname "$csproj")
    (
        cd "$project_dir"
        dotnet pack
        cd ./bin/Release
        echo $(pwd)
        packagePath=$(realpath $(ls -t | head -1))
        dotnet nuget push "$packagePath" \
            -s https://nuget.pkg.github.com/Bizdocs/index.json
    )
done