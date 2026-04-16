#!/usr/bin/env bash

set -euo pipefail
trap cleanup EXIT

TARGET_DIRECTORY="${1:-.}"
TEMPORARY_RENAME_PLAN_FILE=$(mktemp) || exit 1

PARALLEL_JOB_COUNT=$(nproc)
SELECTED_EXTENSION=""

declare -A CHOSEN_EXTENSION_BY_SET

function cleanup() {
  rm -f "$TEMPORARY_RENAME_PLAN_FILE"
}

function detect_extension_candidates() {
  local file_path="$1"
  local extension_candidates

  extension_candidates=$(file --extension --brief "$file_path" 2>/dev/null || true)

  if [[ -z "$extension_candidates" || "$extension_candidates" == "???" ]]; then
    return
  fi

  printf '%s|%s\n' "$file_path" "$extension_candidates"
}

function choose_extension_for_set() {
  local extension_set="$1"
  local -a extension_options=()
  local option_index
  local selected_option

  if [[ -n "${CHOSEN_EXTENSION_BY_SET[$extension_set]:-}" ]]; then
    SELECTED_EXTENSION="${CHOSEN_EXTENSION_BY_SET[$extension_set]}"
    return
  fi

  IFS='/' read -r -a extension_options <<< "$extension_set"

  echo
  echo "Ambiguous extension set: $extension_set"
  for idx in "${!extension_options[@]}"; do
    printf '  [%d] %s\n' "$((idx + 1))" "${extension_options[$idx]}"
  done

  read -rp "Choose extension for ALL matching files [1-${#extension_options[@]}] (Enter=skip): " selected_option < /dev/tty

  if [[ "$selected_option" =~ ^[0-9]+$ ]] && (( selected_option >= 1 && selected_option <= ${#extension_options[@]} )); then
    CHOSEN_EXTENSION_BY_SET[$extension_set]="${extension_options[$((selected_option - 1))]}"
  else
    CHOSEN_EXTENSION_BY_SET[$extension_set]="SKIP"
  fi

  SELECTED_EXTENSION="${CHOSEN_EXTENSION_BY_SET[$extension_set]}"
}

function build_rename_plan() {
  local -a extension_results=()
  local result_line
  local file_path
  local extension_candidates
  local selected_extension

  mapfile -t extension_results < <(
    find "$TARGET_DIRECTORY" -type f ! -regex '.*\.[^/]+$' -print0 |
    parallel -0 -P "$PARALLEL_JOB_COUNT" detect_extension_candidates {}
  )

  for result_line in "${extension_results[@]}"; do
    IFS='|' read -r file_path extension_candidates <<< "$result_line"

    if [[ "$extension_candidates" == */* ]]; then
      choose_extension_for_set "$extension_candidates"
      selected_extension="$SELECTED_EXTENSION"
      if [[ "$selected_extension" == "SKIP" ]]; then
        continue
      fi
    else
      selected_extension="$extension_candidates"
    fi

    if [[ -z "$selected_extension" || "$selected_extension" == "???" ]]; then
      continue
    fi

    printf '%s|%s.%s\n' "$file_path" "$file_path" "$selected_extension" >> "$TEMPORARY_RENAME_PLAN_FILE"
  done
}

function show_rename_plan() {
  echo
  echo "Planned renames:"
  awk -F'|' '{printf "  %s → %s\n", $1, $2}' "$TEMPORARY_RENAME_PLAN_FILE"
}

function confirm_rename_plan() {
  local confirmation

  echo
  read -rp "Proceed? [y/N]: " confirmation < /dev/tty

  [[ "$confirmation" == [yY] ]]
}

function move_one_file() {
  local operation="$1"
  local source_path
  local destination_path

  IFS='|' read -r source_path destination_path <<< "$operation"
  mv -- "$source_path" "$destination_path"
}

function apply_rename_plan() {
  local -a rename_operations=()

  mapfile -t rename_operations < "$TEMPORARY_RENAME_PLAN_FILE"

  printf '%s\n' "${rename_operations[@]}" |
  parallel -P "$PARALLEL_JOB_COUNT" move_one_file {}
}

function main() {
  export -f detect_extension_candidates
  export -f move_one_file
  echo "Building rename plan..."
  build_rename_plan

  if [[ ! -s "$TEMPORARY_RENAME_PLAN_FILE" ]]; then
    echo "Nothing to do."
    exit 0
  fi

  show_rename_plan

  if ! confirm_rename_plan; then
    exit 0
  fi
  echo "Applying rename plan..."
  apply_rename_plan
  echo "Done."
}

main