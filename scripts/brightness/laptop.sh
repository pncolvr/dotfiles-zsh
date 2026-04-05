#!/usr/bin/env bash

if [ $1 -lt 1 ] || [ $1 -gt 100 ]; then
    echo "The first parameter is not between 10 and 100. Exiting with error."
    exit 1
fi

brightnessctl --class=backlight set "$1%" 1>/dev/null 2>/dev/null & disown