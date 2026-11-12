#!/usr/bin/env bash
# Deletes build output and dependencies from projects (see NAMES below).
#
# Usage: clean.sh [-n] [-y] [dir]
#   dir  folder to clean (default: ~/Projects)
#   -n   dry run: only list what would be deleted
#   -y   don't ask for confirmation
#
# Folders that contain files tracked by git are skipped, so a committed bin/
# (scripts, vendored tools) is never deleted.

NAMES=(
    node_modules    # npm / yarn / pnpm
    bin obj         # .NET (bin also covers bin/Debug and bin/Release)
    target          # Rust / Maven
    .dart_tool      # Dart / Flutter
    .gradle         # Gradle
    .venv venv      # Python virtual environments
    __pycache__     # Python bytecode
)

dry_run=0
assume_yes=0
while getopts "ny" opt; do
    case $opt in
        n) dry_run=1;;
        y) assume_yes=1;;
        *) sed -n '4,8p' "$0" | sed 's/^# \{0,1\}//' >&2; exit 1;;
    esac
done
shift $((OPTIND - 1))
root=${1:-$HOME/Projects}

if [[ ! -d $root ]]; then
    echo "Not a directory: $root" >&2
    exit 1
fi
root=$(realpath -- "$root")

# Returns 0 if the folder holds files that git tracks.
function is_tracked() {
    local dir=$1 top
    top=$(git -C "$dir" rev-parse --show-toplevel 2>/dev/null) || return 1
    [[ -n $(git -C "$top" ls-files -- "$dir" 2>/dev/null | head -1) ]]
}

echo "==> Looking for ${NAMES[*]} in $root"
name_args=()
for n in "${NAMES[@]}"; do
    name_args+=(${name_args:+-o} -name "$n")
done

found=()
skipped=()
# -prune: don't look inside a match (no node_modules inside node_modules)
while IFS= read -r -d '' dir; do
    if is_tracked "$dir"; then
        skipped+=("$dir")
    else
        found+=("$dir")
    fi
done < <(find "$root" -name .git -prune -o -type d \( "${name_args[@]}" \) -prune -print0 2>/dev/null)

if (( ${#skipped[@]} )); then
    echo
    echo "==> Skipping ${#skipped[@]} folder(s) with files tracked by git:"
    printf '    %s\n' "${skipped[@]#"$root"/}"
fi

if (( ${#found[@]} == 0 )); then
    echo
    echo "Nothing to clean"
    exit 0
fi

echo
echo "==> Measuring ${#found[@]} folder(s)"
du -sh -- "${found[@]}" 2>/dev/null | sort -h | sed "s|$root/||; s|^|    |"
total=$(du -csh -- "${found[@]}" 2>/dev/null | tail -1 | cut -f1)
echo
echo "Total: $total in ${#found[@]} folder(s)"

if (( dry_run )); then
    echo "Dry run, nothing deleted"
    exit 0
fi

if (( ! assume_yes )); then
    read -rp "Delete them? [y/N] " answer
    [[ $answer == [yY] ]] || { echo "Cancelled"; exit 0; }
fi

echo
echo "==> Deleting"
failed=0
for dir in "${found[@]}"; do
    rm -rf -- "$dir" || failed=1
done

if (( failed )); then
    echo "Some folders could not be deleted, see errors above" >&2
    exit 1
fi
echo "Freed $total"
