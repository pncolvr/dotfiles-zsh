#!/usr/bin/env bash
# Read-only explanation of the status manager's automatic work detection.
set -euo pipefail
state_file=${1:?state file is required}
work_directory=${2-}
shift 2
check_files=false
if [[ $state_file == --has-work-files ]]; then check_files=true; state_file=; fi
work_directory=${work_directory%/}
fields=()
errors=()
for pattern in "$@"; do
    if processes=$(pgrep -u "$USER" -x -l -- "$pattern"); then
        while IFS=' ' read -r pid name; do
            [[ $pid =~ ^[0-9]+$ && -n $name ]] || continue
            executable=$(readlink -- "/proc/$pid/exe" 2>/dev/null || true)
            fields+=("process" "$name" "$executable")
        done <<< "$processes"
    else
        result=$?
        (( result == 1 )) || errors+=("Could not check configured process: $pattern")
    fi
done
if [[ -n $work_directory ]]; then
    if command -v lsof >/dev/null 2>&1; then
        report=$(mktemp "${XDG_RUNTIME_DIR:-/tmp}/status-detection.XXXXXX")
        trap 'rm -f -- "$report"' EXIT
        result=0
        lsof -n -P -a -u "$USER" -F0pcfn > "$report" 2>/dev/null || result=$?
        if (( result > 1 )); then errors+=("Could not inspect open work files."); fi
        name= descriptor=
        while IFS= read -r -d '' field; do
            field=${field#$'\n'}
            case ${field:0:1} in
                p) name=; descriptor= ;;
                c) name=${field:1} ;;
                f) descriptor=${field:1} ;;
                n)
                    path=${field:1}
                    [[ -n $name && ( $path == "$work_directory" || $path == "$work_directory/"* ) ]] || continue
                    kind=file
                    [[ $descriptor != cwd ]] || kind=directory
                    fields+=("$kind" "$name" "$path")
                    ;;
            esac
        done < "$report"
    else errors+=("Open work-file detection requires lsof."); fi
fi
if $check_files; then
    ((${#fields[@]} > 0))
    exit $?
fi
matches=$( { if ((${#fields[@]})); then printf '%s\0' "${fields[@]}"; fi; } | jq -Rs '
    split("\u0000") | if length == 1 and .[0] == "" then [] else .[:-1] end
    | . as $fields | [range(0; length; 3) as $i | {method:$fields[$i], name:$fields[$i+1], path:$fields[$i+2]}]
    | group_by(.name) | map({name:.[0].name, methods:map(.method)|unique, paths:map(.path)|map(select(length > 0))|unique})')
error_report=$( { if ((${#errors[@]})); then printf '%s\0' "${errors[@]}"; fi; } | jq -Rs 'split("\u0000") | if length == 1 and .[0] == "" then [] else .[:-1] end')
source=automatic
[[ ! -f $state_file ]] || source=manual
jq -n --arg source "$source" --arg workDirectory "$work_directory" --argjson matches "$matches" --argjson errors "$error_report" \
    '{source:$source, automaticStatus:(if ($matches|length)>0 then "work" else "personal" end), workDirectory:$workDirectory, matches:$matches, errors:$errors}'
