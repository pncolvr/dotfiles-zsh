#!/usr/bin/env bash

get_display_model() {
    local display_num=$1
    local verbose_data=$2
    local model=$(echo "$verbose_data" | sed -n "/^Display $display_num$/,/^Display [0-9]*$/p" | grep "Monitor Model Id:" | sed 's/.*Monitor Model Id: *\(.*\)$/\1/' | tr -d '\n\r')
    
    if [ -z "$model" ]; then
        model="Unknown Model"
    fi
    
    echo "$model"
}

verbose_output=$(ddcutil detect --verbose 2>/dev/null)
displays=$(echo "$verbose_output" | grep "^Display [0-9]" | grep -o "[0-9]*")

if [ $# -eq 0 ]; then
    if [ -z "$displays" ]; then
        echo "No DDC/CI capable monitors found."
        exit 1
    fi
    
    for d in $displays
    do
        model=$(get_display_model "$d" "$verbose_output")
        echo -n "Display $d ($model): "
        output=$(ddcutil --display "$d" getvcp 10 2>/dev/null)
        current=$(echo "$output" | grep "current value" | sed 's/.*current value = *\([0-9]*\).*/\1/')
        max=$(echo "$output" | grep "max value" | sed 's/.*max value = *\([0-9]*\).*/\1/')
        
        if [ -n "$current" ] && [ -n "$max" ]; then
            echo "${current}% of ${max}%"
        else
            echo "Unable to read brightness"
        fi
    done
    exit 0
fi

if [ -z "$1" ] || ! [[ "$1" =~ ^[0-9]+$ ]] || [ "$1" -lt 1 ] || [ "$1" -gt 100 ]; then
    echo "Brightness value must be an integer between 1 and 100. Exiting with error."
    exit 1
fi

if [ -z "$displays" ]; then
    echo "No DDC/CI capable monitors found."
    exit 1
fi

num_displays=$(echo "$displays" | wc -w)
for d in $displays
do
    model=$(get_display_model "$d" "$verbose_output")
    ddcutil --display "$d" setvcp 10 "$1" 1>/dev/null 2>/dev/null & disown
    echo "Display $d ($model): brightness set to $1%"
done
