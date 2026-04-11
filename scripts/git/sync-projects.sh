#!/usr/bin/env bash

source "$ZDOTDIR"/scripts/_common.sh
env=$(get_env_file "${BASH_SOURCE[0]:-0}")
source $env
# env file sample
# DELIMITER=";"
# EDITOR="code"
# BYPASS_ASK_USER_MAKE_EXECUTABLE=false
# IGNORE_URL=
# PROJECTS_JSON=
# PROJECT_CATEGORY=

set -e

function prompt() {
    local prompt="$1"
    local yes_action="$2"
    local no_action="$3"
    read -p "$prompt (Y/n) " -n 1 -r < /dev/tty
    echo
    if [[ -z $REPLY || $REPLY =~ ^[Yy]$ ]]; then
        eval "$yes_action"
    else
        eval "$no_action"
    fi
}

function do_pull() {
    local repo="$1"
    cd "$repo"
    echo -n "Pulling latest changes... "
    git pull > /dev/null

    if [ $? -ne 0 ]; then
        echo "Merge conflicts detected!"
        git diff --name-only --diff-filter=U
        prompt "Open '$EDITOR' to resolve conflicts?" "$EDITOR $path < /dev/tty &" ":"
        return 1
    else
        echo "Pull completed successfully"
    fi
}

function do_push() {
    local repo="$1"
    cd "$repo"
    local branch="$(git rev-parse --abbrev-ref HEAD)"
    if git diff origin/"$branch"..HEAD --quiet; then
        echo "No changes to push"
        return 0
    fi

    prompt "Push changes?" "git push" ":"
 
    if [ $? -ne 0 ]; then
        echo "Push failed"
        return 1
    fi
}

function ask_add_and_commit() {
    read -p "Enter commit message: " commit_msg < /dev/tty
        
    if [ -z "$commit_msg" ]; then
        echo "Commit message cannot be empty"
        return 1
    fi

    git add .
    git commit -m "$commit_msg"
    echo "Changes committed successfully"
}

function do_status_and_commit() {
    local repo="$1"
    cd "$repo"
    if git diff-index --quiet HEAD --; then
        echo "No changes to commit"
        return 0
    fi

    echo "Changes detected:"
    git status --short

    prompt "Do you want to add all changes and commit?" ask_add_and_commit "return 1"
}

function make_executable() {
    file="$1"
    echo "File '$file' is now executable."
    chmod +x "$file"
}

function ask_user_make_executable() {
    local file="$1"
    if [ "$BYPASS_ASK_USER_MAKE_EXECUTABLE" = false ]; then
        prompt "File '$file' is not executable. Do you want to make it executable?" "make_executable $file" ":"
    else
        make_executable "$file"
    fi
}

function handle_executables() {
    repo="$1"
    while read -r file
    do
        if [[ ! -x "$file" ]]; then
            ask_user_make_executable "$file"
        fi
    done < <(find "$repo" -type f -name "*.ps1" -o -name "*.sh")
}

function main () {
    local name="$1"
    local path="$2"
    echo "Processing: $name"
    do_status_and_commit "$path"
    do_pull "$path"
    do_push "$path"
    handle_executables "$path"
    echo
}

while IFS="$DELIMITER" read -r name path;
do
(
    main "$name" "$path"
)
done < <(jq -r --arg category "$PROJECT_CATEGORY" \
    --arg ignore_url "$IGNORE_URL" \
    --arg delimiter "$DELIMITER" \
    '.[] | select(.category==$category and .url != $ignore_url and .url != null) | [.name, .rootPath] | join($delimiter)' "$PROJECTS_JSON")