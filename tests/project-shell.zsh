#!/usr/bin/env zsh
# Synthetic projects only; do not source the real user/project environment.
setopt pipe_fail
zmodload zsh/parameter
project_test_module=${PROJECT_TEST_MODULE:-${${(%):-%x}:A:h:h}/scripts/shell/project-shell.zsh}
project_test_rc=${PROJECT_TEST_RC:-${${(%):-%x}:A:h:h}/.zshrc}
project_test_dir=$(mktemp -d /tmp/zsh-project-shell-test.XXXXXXXX) || exit 1
trap 'rm -rf -- "$project_test_dir"' EXIT
project_test_fail() { print -u2 -r -- "FAIL: $1"; exit 1; }
mkdir -p "$project_test_dir/Project one/nested/deep" "$project_test_dir/Project one-neighbor" \
  "$project_test_dir/outside" "$project_test_dir/Project one/completions" "$project_test_dir/home" "$project_test_dir/bin"
export PROJECT_TEST_ROOT="$project_test_dir/Project one"
export PROJECT_TEST_LOG="$project_test_dir/loads"
cat > "$PROJECT_TEST_ROOT/helper.zsh" <<'HELPER'
print -r -- load >> "$PROJECT_TEST_LOG"
PROJECT_TEST_VALUE='literal $(touch NEVER)'
export PROJECT_TEST_ADDED='private test value'
typeset -g -a PROJECT_TEST_TYPED=(one 'two words')
function project_test_command { print -r -- project; }
alias project_test_alias='print -r -- project-alias'
alias -g PROJECT_TEST_GLOBAL_ALIAS='| cat'
alias -s projecttest='print -r -- suffix'
fpath=( "$PROJECT_TEST_ROOT/completions" "${fpath[@]}" )
path=( "$PROJECT_TEST_ROOT/bin" "${path[@]}" )
autoload -Uz _project_test_completion
compdef _project_test_completion project_test_command
HELPER
cat > "$PROJECT_TEST_ROOT/completions/_project_test_completion" <<'COMPLETION'
print -r -- completed
COMPLETION
cat > "$project_test_dir/second.zsh" <<'HELPER'
PROJECT_TEST_VALUE=second
function project_test_command { print -r -- second; }
HELPER
cat > "$project_test_dir/failure.zsh" <<'HELPER'
PROJECT_TEST_VALUE=broken
PROJECT_TEST_FAILURE=temporary
function project_test_failure_command { :; }
return 1
HELPER
autoload -Uz compinit
compinit -D || project_test_fail 'initialize synthetic completions'
PROJECT_TEST_VALUE=original
PROJECT_TEST_TYPED=scalar
function project_test_command { print -r -- original; }
alias project_test_alias='print -r -- original-alias'
_comps[project_test_command]=_original_completion
project_test_original_fpath=( "${fpath[@]}" )
project_test_original_path=( "${path[@]}" )
function project_test_existing_hook { :; }
chpwd_functions=(project_test_existing_hook)
typeset -gA PROJECT_SHELLS=( "$PROJECT_TEST_ROOT" "$PROJECT_TEST_ROOT/helper.zsh" )
cd "$PROJECT_TEST_ROOT/nested" || exit 1
source "$project_test_module" || project_test_fail 'load module when terminal starts inside project'
[[ $PROJECT_TEST_VALUE == 'literal $(touch NEVER)' && $(project_test_command) == project ]] || project_test_fail 'startup inside project'
[[ $PROJECT_TEST_ADDED == 'private test value' && $parameters[PROJECT_TEST_ADDED] == *export* ]] || project_test_fail 'project export'
[[ $parameters[PROJECT_TEST_TYPED] == array && $PROJECT_TEST_TYPED[2] == 'two words' ]] || project_test_fail 'project array type'
[[ $aliases[project_test_alias] == 'print -r -- project-alias' && $_comps[project_test_command] == _project_test_completion ]] || project_test_fail 'project alias/completion'
[[ $galiases[PROJECT_TEST_GLOBAL_ALIAS] == '| cat' && $saliases[projecttest] == 'print -r -- suffix' ]] || project_test_fail 'global and suffix aliases'
[[ $(_project_test_completion) == completed ]] || project_test_fail 'project completion can autoload'
cd "$PROJECT_TEST_ROOT/nested/deep" || exit 1
[[ $(wc -l < "$PROJECT_TEST_LOG") -eq 1 ]] || project_test_fail 'nested cd must not reload helper'
_comps[project_test_unrelated]=_unrelated_completion
PROJECT_TEST_UNRELATED=keep
function project_test_unrelated_command { :; }
cd "$project_test_dir/outside" || exit 1
[[ $PROJECT_TEST_VALUE == original && $(project_test_command) == original && $PROJECT_TEST_TYPED == scalar ]] || project_test_fail 'restore previous variables/functions and types'
(( ! ${+PROJECT_TEST_ADDED} && ! ${+functions[_project_test_completion]} )) || project_test_fail 'remove project-only export and cached completion'
[[ $aliases[project_test_alias] == 'print -r -- original-alias' && $_comps[project_test_command] == _original_completion ]] || project_test_fail 'restore previous alias/completion'
(( ! ${+galiases[PROJECT_TEST_GLOBAL_ALIAS]} && ! ${+saliases[projecttest]} )) || project_test_fail 'remove scoped global and suffix aliases'
[[ ${(j:|:)fpath} == ${(j:|:)project_test_original_fpath} && ${(j:|:)path} == ${(j:|:)project_test_original_path} ]] || project_test_fail 'restore completion/executable search paths'
[[ $_comps[project_test_unrelated] == _unrelated_completion && $PROJECT_TEST_UNRELATED == keep ]] || project_test_fail 'preserve unrelated changes'
(( ${+functions[project_test_unrelated_command]} )) || project_test_fail 'preserve unrelated function'
[[ ! -e "$PROJECT_TEST_ROOT/nested/NEVER" ]] || project_test_fail 'literal variable text must not execute'
cd "$project_test_dir/Project one-neighbor" || exit 1
[[ $(wc -l < "$PROJECT_TEST_LOG") -eq 1 ]] || project_test_fail 'reject sibling with same prefix'
ln -s "$PROJECT_TEST_ROOT" "$project_test_dir/link"
cd "$project_test_dir/link/nested" || exit 1
[[ $(project_test_command) == project ]] || project_test_fail 'physical path through symlink'
PROJECT_SHELLS[$PROJECT_TEST_ROOT/nested/deep]="$project_test_dir/second.zsh"
cd "$PROJECT_TEST_ROOT/nested/deep" || exit 1
[[ $(project_test_command) == second && $PROJECT_TEST_VALUE == second ]] || project_test_fail 'most specific project root'
cd "$PROJECT_TEST_ROOT/nested" || exit 1
[[ $(project_test_command) == project ]] || project_test_fail 'return from nested scope'
source "$project_test_module" || project_test_fail 'reload shared module'
[[ $(project_test_command) == project && ${#${(M)chpwd_functions:#_project_shell_sync}} -eq 1 ]] || project_test_fail 'reload has one hook and active helpers'
(( ${chpwd_functions[(Ie)project_test_existing_hook]} )) || project_test_fail 'preserve existing directory hooks'
cd "$project_test_dir/outside" || exit 1
PROJECT_SHELLS[$project_test_dir/failing]="$project_test_dir/failure.zsh"
mkdir "$project_test_dir/failing"
cd "$project_test_dir/failing" 2> "$project_test_dir/error" || project_test_fail 'helper failure must not break cd'
[[ $PROJECT_TEST_VALUE == original && -z $_project_shell_active_root ]] || project_test_fail 'failed helper restores prior scope'
(( ! ${+PROJECT_TEST_FAILURE} && ! ${+functions[project_test_failure_command]} )) || project_test_fail 'failed helper rollback'
[[ $(<"$project_test_dir/error") == 'Project shell helper failed; shell changes were restored.' ]] || project_test_fail 'clear load failure'
cd "$project_test_dir/outside" || exit 1
PROJECT_SHELLS=()
source "$project_test_module" || project_test_fail 'empty project mapping'
print -r -- 'PASS: startup, nested/symlink paths, scope switching, aliases, functions, exports, types, cached completions, reload and rollback'

# Exercise actual .zshrc startup/reload with optional private configuration.
mkdir -p "$project_test_dir/config/scripts/shell"
cp "$project_test_module" "$project_test_dir/config/scripts/shell/project-shell.zsh"
cp "$project_test_rc" "$project_test_dir/config/.zshrc"
printf '#!/bin/sh\nexit 0\n' > "$project_test_dir/bin/zoxide"
chmod +x "$project_test_dir/bin/zoxide"
export HOME="$project_test_dir/home" ZDOTDIR="$project_test_dir/config" WAYLAND_DISPLAY=synthetic \
  XDG_CACHE_HOME="$project_test_dir/cache" PROJECT_TEST_CONFIG="$project_test_dir/config"
export PATH="$project_test_dir/bin:$PATH"
cd "$PROJECT_TEST_ROOT/nested" || exit 1
zsh -fic 'source "$PROJECT_TEST_CONFIG/.zshrc"; [[ -z $_project_shell_active_root ]]' \
  > "$project_test_dir/startup-log" 2>&1 || { cat "$project_test_dir/startup-log"; project_test_fail 'optional missing .zshrc.env'; }
cat > "$project_test_dir/config/.zshrc.env" <<'ENV'
typeset -gA PROJECT_SHELLS=( "$PROJECT_TEST_ROOT" "$PROJECT_TEST_ROOT/helper.zsh" )
ENV
zsh -fic '
  source "$PROJECT_TEST_CONFIG/.zshrc"
  [[ $(project_test_command) == project ]] || exit 1
  source "$PROJECT_TEST_CONFIG/.zshrc"
  [[ $(project_test_command) == project && ${#${(M)chpwd_functions:#_project_shell_sync}} -eq 1 ]] || exit 1
  cd "$HOME"
  (( ! ${+functions[project_test_command]} && ! ${+PROJECT_TEST_ADDED} )) || exit 1
' > "$project_test_dir/startup-log" 2>&1 || { cat "$project_test_dir/startup-log"; project_test_fail 'real .zshrc startup/reload cleanup'; }
print -r -- 'PASS: real .zshrc tolerates missing private config, loads a VS Code-style cwd and restores clean state after reload/leave'
