#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env

function show_usage() {
    cat << EOF
Usage: "${BASH_SOURCE[0]:-0}" -r <projects_root> -d <destination_json> [-a <additional_projects_file>] [-v]

Create JSON file of VS Code projects and workspaces.

Options:
    -r <path>    Projects root directory (mandatory)
    -d <path>    Destination JSON file path (mandatory)
    -a <path>    File containing additional project directories (optional)
    -v           Verbose output
    -h           Show this help message

Example:
    "${BASH_SOURCE[0]:-0}" -r /home/user/Projects -d ~/.cache/code_projects.json -a ~/.config/additional_projects.txt -v
EOF
}

function debug_log() {
    if [[ "$VERBOSE" == "true" ]]; then
        printf "[DEBUG] %s\n" "$*" >&2
    fi
}

function parse_args() {
    local OPTIND
    while getopts ":r:a:d:vh" opt; do
        case $opt in
            r)
                PROJECTS_ROOT="$OPTARG"
                debug_log "Projects root set to: $PROJECTS_ROOT"
                ;;
            a)
                ADDITIONAL_PROJECTS_FILE="$OPTARG"
                debug_log "Additional projects file set to: $ADDITIONAL_PROJECTS_FILE"
                ;;
            d)
                DESTINATION_JSON="$OPTARG"
                debug_log "Destination JSON set to: $DESTINATION_JSON"
                ;;
            v)
                VERBOSE=true
                debug_log "Verbose mode enabled"
                ;;
            h)
                show_usage
                exit 0
                ;;
            \?)
                print_error_message "Invalid option: -$OPTARG"
                show_usage
                exit 1
                ;;
            :)
                print_error_message "Option -$OPTARG requires an argument"
                show_usage
                exit 1
                ;;
        esac
    done

    if [[ -z "$PROJECTS_ROOT" ]]; then
        print_error_message "Projects root directory (-r) is required"
        show_usage
        exit 1
    fi

    if [[ -z "$DESTINATION_JSON" ]]; then
        print_error_message "Destination JSON path (-d) is required"
        show_usage
        exit 1
    fi

    PROJECTS_ROOT="${PROJECTS_ROOT%/}"
    if [[ -n "$ADDITIONAL_PROJECTS_FILE" ]]; then
        ADDITIONAL_PROJECTS_FILE="${ADDITIONAL_PROJECTS_FILE%/}"
    fi
    DESTINATION_JSON="${DESTINATION_JSON%/}"
}

function collect_project_directories() {
    local -a project_dirs=()
    
    debug_log "Scanning immediate child directories of root path: $PROJECTS_ROOT"
    
    if [[ -d "$PROJECTS_ROOT" ]]; then
        while IFS= read -r -d '' dir; do
            local project_name="$(basename "$dir")"
            debug_log "Discovered root child: $dir"
            project_dirs+=("$dir")
        done < <(find "$PROJECTS_ROOT" -maxdepth 1 -type d -not -name "$(basename "$PROJECTS_ROOT")" -print0)
    else
        print_error_message "Projects root directory does not exist: $PROJECTS_ROOT"
        exit 1
    fi
    
    if [[ -n "$ADDITIONAL_PROJECTS_FILE" ]]; then
        debug_log "Reading additional projects from file: $ADDITIONAL_PROJECTS_FILE"
        if [[ -f "$ADDITIONAL_PROJECTS_FILE" ]]; then
            while IFS= read -r line; do
                # Skip blank lines
                if [[ -n "${line// }" ]]; then
                    debug_log "Adding project from file line: $line"
                    project_dirs+=("${line%/}")
                else
                    debug_log "Skipping blank line in additional projects file"
                fi
            done < "$ADDITIONAL_PROJECTS_FILE"
        else
            debug_log "Additional projects file not found: $ADDITIONAL_PROJECTS_FILE"
        fi
    else
        debug_log "No additional projects file path supplied"
    fi
    
    printf '%s\n' "${project_dirs[@]}"
}

function convert_to_https_url() {
    local git_url="$1"
    
    if [[ "$git_url" =~ ^git@([^:]+):(.+)\.git$ ]]; then
        echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    elif [[ "$git_url" =~ ^git@([^:]+):(.+)$ ]]; then
        echo "https://${BASH_REMATCH[1]}/${BASH_REMATCH[2]}"
    else
        echo "${git_url%.git}"
    fi
}

function get_git_remote_url() {
    local project_dir="$1"
    local project_name="$(basename "$project_dir")"
    
    if [[ -d "$project_dir/.git" ]] || [[ -f "$project_dir/.git" ]]; then
        debug_log "[Project:$project_name] Git repository detected (.git dir or file), checking remote URL"
        local remote_url
        remote_url=$(git -C "$project_dir" remote get-url origin 2>/dev/null)
        if [[ -n "$remote_url" ]]; then
            local https_url
            https_url=$(convert_to_https_url "$remote_url")
            debug_log "[Project:$project_name] Git remote URL: $remote_url → $https_url"
            echo "$https_url"
            return
        else
            debug_log "[Project:$project_name] No origin remote found, checking dotfiles fallback if applicable"
        fi
    fi
    if [[ -d "$HOME/.cfg" ]] && [[ "$project_dir" != "$HOME/Projects"* ]]; then
        debug_log "[Project:$project_name] Checking if managed by dotfiles repository"
        local remote_url
        remote_url=$(git --git-dir="$HOME/.cfg/" --work-tree="$HOME" remote get-url origin 2>/dev/null)
        if [[ -n "$remote_url" ]]; then
            local https_url
            https_url=$(convert_to_https_url "$remote_url")
            debug_log "[Project:$project_name] Dotfiles remote URL: $remote_url → $https_url"
            echo "$https_url"
        else
            debug_log "[Project:$project_name] No origin remote found in dotfiles repo"
            echo "null"
        fi
    else
        debug_log "[Project:$project_name] Not a git repository"
        echo "null"
    fi
}

function get_project_category() {
    local git_url="$1"
    local project_dir="$2"

    if [[ "$git_url" != "null" ]] && [[ "$git_url" == *"$WORK_GIT_URL_MATCH"* ]]; then
        echo "$PROJECT_CATEGORY_WORK"
    elif [[ -n "$WORK_PROJECTS_ROOT" ]] && [[ "$project_dir" == "$WORK_PROJECTS_ROOT" || "$project_dir" == "$WORK_PROJECTS_ROOT"/* ]]; then
        echo "$PROJECT_CATEGORY_WORK"
    else
        echo "$PROJECT_CATEGORY_PERSONAL"
    fi
}

function find_project_workspaces() {
    local project_dir="$1"
    local project_name="$(basename "$project_dir")"
    
    debug_log "[Project:$project_name] Scanning for *.code-workspace files (excluding VS Code config)"
    
    local -a workspaces=()
    if [[ -d "$project_dir" ]]; then
        while IFS= read -r -d '' workspace_file; do
            local workspace_name="$(basename "$workspace_file" .code-workspace)"
            debug_log "[Project:$project_name] Found workspace: $workspace_file"
            
            local workspace_json=$(jq -n \
                --arg name "$workspace_name" \
                --arg path "$workspace_file" \
                '{name: $name, path: $path}')
            workspaces+=("$workspace_json")
        done < <(find "$project_dir" -name "*.code-workspace" -not -path "*/.config/Code/*" -type f -print0 2>/dev/null)
        
        debug_log "[Project:$project_name] Total workspaces: ${#workspaces[@]}"
    else
        debug_log "[Project:$project_name] Path does not exist: $project_dir"
    fi
    
    local workspaces_array="[]"
    if [[ ${#workspaces[@]} -gt 0 ]]; then
        workspaces_array=$(printf '%s\n' "${workspaces[@]}" | jq -s '.')
    fi
    
    local git_url
    git_url=$(get_git_remote_url "$project_dir")

    local category
    category=$(get_project_category "$git_url" "$project_dir")
    
    jq -n \
        --arg name "$project_name" \
        --arg rootPath "$project_dir" \
        --arg gitRemoteUrl "$git_url" \
        --arg category "$category" \
        --argjson workspaces "$workspaces_array" \
        '{name: $name, rootPath: $rootPath, url: ($gitRemoteUrl | if . == "null" then null else . end), category: $category, workspaces: $workspaces}'
}

function process_projects_parallel() {
    local -a project_dirs
    mapfile -t project_dirs < <(collect_project_directories)
    
    debug_log "Processing ${#project_dirs[@]} projects with parallel processing"
    
    if [[ ${#project_dirs[@]} -eq 0 ]]; then
        print_error_message "No project directories found"
        exit 1
    fi
    
    export -f find_project_workspaces get_git_remote_url get_project_category convert_to_https_url debug_log
    export VERBOSE
    export WORK_GIT_URL_MATCH WORK_PROJECTS_ROOT PROJECT_CATEGORY_WORK PROJECT_CATEGORY_PERSONAL
    
    printf '%s\n' "${project_dirs[@]}" | \
        parallel -j "$(nproc)" find_project_workspaces {} | \
        jq -s 'sort_by(.name)'
}

function  process_projects_sequential() {
    local -a project_dirs
    mapfile -t project_dirs < <(collect_project_directories)
    
    debug_log "Processing ${#project_dirs[@]} projects sequentially"
    
    if [[ ${#project_dirs[@]} -eq 0 ]]; then
        print_error_message "No project directories found"
        exit 1
    fi
    
    local -a project_objects=()
    for project_dir in "${project_dirs[@]}"; do
        local project_json=$(find_project_workspaces "$project_dir")
        project_objects+=("$project_json")
    done
    
    if [[ ${#project_objects[@]} -gt 0 ]]; then
        printf '%s\n' "${project_objects[@]}" | jq -s 'sort_by(.name)'
    else
        echo "[]"
    fi
}

function filter_workspaces() {
    local json="$1"

    local workspace_list
    workspace_list=$(echo "$json" | jq -r '.[] | .name as $proj | .workspaces[] | "\($proj) > \(.name)\t\(.path)"')

    if [[ -z "$workspace_list" ]]; then
        debug_log "No workspaces found, skipping filter"
        echo "$json"
        return
    fi

    local fzf_output
    fzf_output=$(printf '%s\n' "$workspace_list" | \
        fzf --multi \
            --bind 'start:select-all' \
            --bind 'ctrl-a:toggle-all' \
            --delimiter=$'\t' \
            --with-nth=1 \
            --header=$'Tab/Shift-Tab: toggle & move  Ctrl-A: toggle all  Enter: confirm  Esc: keep all\nDeselect workspaces to omit:' \
            --prompt='Workspaces to keep> ')

    local fzf_exit=$?

    if [[ $fzf_exit -eq 130 ]]; then
        debug_log "fzf cancelled, keeping all workspaces"
        echo "$json"
        return
    fi

    local paths_json
    paths_json=$(printf '%s\n' "$fzf_output" | awk -F'\t' '{print $2}' | jq -R -s 'split("\n") | map(select(length > 0))')

    echo "$json" | jq --argjson paths "$paths_json" \
        '[.[] | .workspaces = [.workspaces[] | select(.path | IN($paths[]))]]'
}

function main() {
    debug_log "Script start. ProjectsRoot='$PROJECTS_ROOT'; AdditionalProjectsFile='$ADDITIONAL_PROJECTS_FILE'; DestinationJson='$DESTINATION_JSON'"
    
    local required_deps=("jq" "find")
    if command -v parallel >/dev/null 2>&1; then
        debug_log "GNU parallel detected - will use parallel processing"
        required_deps+=("parallel")
    else
        debug_log "GNU parallel not available - will use sequential processing"
    fi
    
    check_dependencies "${required_deps[@]}"
    
    local dest_dir="$(dirname "$DESTINATION_JSON")"
    debug_log "Destination directory resolved to: $dest_dir"
    
    if [[ ! -d "$dest_dir" ]]; then
        debug_log "Destination directory does not exist. Creating..."
        mkdir -p "$dest_dir" || {
            print_error_message "Failed to create destination directory: $dest_dir"
            exit 1
        }
    else
        debug_log "Destination directory already exists"
    fi
    
    debug_log "Sorting and serializing project list..."
    
    local final_json
    if command -v parallel >/dev/null 2>&1; then
        final_json=$(process_projects_parallel)
    else
        final_json=$(process_projects_sequential)
    fi

    final_json=$(filter_workspaces "$final_json")

    echo "$final_json" > "$DESTINATION_JSON" || {
        print_error_message "Failed to write JSON to: $DESTINATION_JSON"
        exit 1
    }
    
    debug_log "JSON written to: $DESTINATION_JSON"
    
    local project_count
    project_count=$(echo "$final_json" | jq 'length')
    debug_log "Total projects collected: $project_count"
    
    print_success_message "Updated projects JSON: $DESTINATION_JSON"
    
    if [[ "$VERBOSE" == "true" ]]; then
        print_success_message "$(echo "$final_json" | jq -r '.[] | "  \(.name) (\(.workspaces | length) workspaces)"')"
    fi
}

parse_args "$@"
main