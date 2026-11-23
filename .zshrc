if (( $+functions[_project_shell_unload] )); then
  _project_shell_unload
fi

# zmodload zsh/zprof

autoload -Uz compinit
zmodload zsh/complist
autoload -U run-help

_zcompdump="${ZDOTDIR:-$HOME}/.zcompdump"
if [[ -n "$_zcompdump"(#qN.mh+24) ]]; then
  compinit -d "$_zcompdump"
  touch "$_zcompdump"
else
  compinit -C -d "$_zcompdump"
fi
if [[ -s "$_zcompdump" && ( ! -s "${_zcompdump}.zwc" || "$_zcompdump" -nt "${_zcompdump}.zwc" ) ]]; then
  zcompile "$_zcompdump"
fi
unset _zcompdump

if [[ -r "${(%):-%x}.env" ]]; then
  source "${(%):-%x}.env"
fi

# bindkey docs
# cat -v # to find out the escape sequences for keys if needed
# https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html
# https://zsh.sourceforge.io/Doc/Release/Shell-Builtin-Commands.html

bindkey '^R' history-incremental-search-backward # ctrl + r
bindkey '^S' history-incremental-search-forward # ctrl + s

bindkey '^[[Z' reverse-menu-complete # shift + tab
bindkey -M menuselect '^[' send-break # escape key
bindkey '^H' backward-delete-word # ctrl + backspace
bindkey '^[[3;5~' delete-word # ctrl + delete
bindkey '^[[1;5D' backward-word # ctrl + left arrow
bindkey '^[[1;5C' forward-word  # ctrl + right arrow
bindkey '^[[H' beginning-of-line  # home key
bindkey '^[[F' end-of-line  # end key
bindkey '^A' beginning-of-line # ctrl + a
bindkey '^E' end-of-line # ctrl + e
bindkey '^W' backward-kill-word # ctrl + w (not limited to the insert start like vi-backward-kill-word)
bindkey '^[.' insert-last-word # alt + . (repeat to cycle through previous commands' last args)
bindkey '^U' backward-kill-line # ctrl + u (cut from cursor to line start into the kill ring)
bindkey '^Y' yank # ctrl + y (paste the last cut text back)

# list the custom keybinds defined in this file: description, keymap and widget
function keybinds() {
  local line desc keymap
  local -a words
  while IFS= read -r line; do
    [[ $line == *'#'* ]] && desc="${line#*\# }" || desc=""
    words=(${(Q)${(z)line%%\#*}})
    keymap="main"
    if [[ ${words[2]} == "-M" ]]; then
      keymap=${words[3]}
      words=(${words[1]} ${words[4,-1]})
    fi
    printf '%-36s \e[2m%-10s\e[0m %s\n' "${words[3]}" "$keymap" "${desc:-${words[2]}}"
  done < <(grep -E '^[[:space:]]*bindkey ' "$ZDOTDIR/.zshrc")
}

function _zle_paste_clipboard() {
  local clip=""
  clip="$(wl-paste --no-newline 2>/dev/null)"
  [[ -z "$clip" ]] && return 0

  LBUFFER+="$clip"
}

function _pick_history_entry() {
  local value
  value=$(history 0 | fzf --smart-case --tac | sed -E 's/^[[:space:]]*[0-9]+[[:space:]]+//')
  value="${value%$'\n'}"
  printf '%s' "$value"
}

function _zle_history_to_buffer() {
  local value
  value="$(_pick_history_entry)"
  [[ -z "$value" ]] && zle redisplay && return 0

  LBUFFER+="$value"
  zle redisplay
}

zle -N _zle_paste_clipboard # define the zle widget for pasting from clipboard
zle -N _zle_history_to_buffer # define the zle widget for loading history into the prompt
bindkey '^V' _zle_paste_clipboard # for regular mode in zsh, to allow pasting with ctrl + v
bindkey -M viins '^V' _zle_paste_clipboard # for vim mode in zsh, to allow pasting with ctrl + v
bindkey '^[h' _zle_history_to_buffer # alt + h
bindkey -M viins '^[h' _zle_history_to_buffer # alt + h in vim insert mode

HISTFILE="${HISTFILE:-${ZDOTDIR:-$HOME}/.zsh_history}"
HISTSIZE=10000
SAVEHIST=$HISTSIZE

zstyle ':completion:*' completer _expand_alias _complete _ignored
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}:di=37:ma=30;47"
zstyle ':completion:*:*:cd:*' list-colors 'di=37:fi=37:ma=30;47'
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "${XDG_CACHE_HOME:-$HOME/.cache}/zsh/.zcompcache"

export EDITOR='nvim'
export VISUAL='nvim'
export FILE_BROWSER='pcmanfm-qt'

NAS_FOLDER='/mnt/hephaestus'
SCRIPTS="$ZDOTDIR/scripts"
HEPHAESTUS_IP='192.168.1.3'

alias ls='ls --human-readable --color=always --group-directories-first --time-style="+%Y-%m-%d %H:%M:%S"'
alias ll='ls -la'
alias rm='rm -I --preserve-root'
alias cp='cp -i'
alias mv='mv -i'
alias mkdir='mkdir -p'

# alias extract='eval $SCRIPTS/archives/extract.sh'
# alias archive='eval $SCRIPTS/archives/create.sh'

alias bios='systemctl reboot --firmware-setup'

alias reload-zsh='source ~/.config/zsh/.zshrc'
alias edit-zsh='code ~/.config/zsh/.zshrc'

alias nas='cd $NAS_FOLDER'

alias bazecore-update='$SCRIPTS/bazecor/update.sh'

alias cd='z'

alias ff='fastfetch'
alias neofetch='fastfetch'

alias updatemirrors='rate-mirrors arch --max-delay=3600 | sudo tee /etc/pacman.d/mirrorlist && eos-rankmirrors && sudo cachyos-rate-mirrors'

function h {
  local value
  value="$(_pick_history_entry)"
  value="${value%$'\n'}"
  [[ -z "$value" ]] && return 0
  wl-copy "$value"
}

alias clear="clear && printf '\e[3J'"
alias testmic="arecord -f cd | aplay"

alias browser='quickshell-browser'

alias heph-ssh='ssh pncolvr@$HEPHAESTUS_IP'
alias heph-ping='ping $HEPHAESTUS_IP'

# alias dotnet-update-rid='sudo pwsh -Command $SCRIPTS/dotnet/update-dotnet-endeavouros.ps1'

alias zathura-update-books="$HOME/.config/hypr/scripts/filebrowser/books-pick.sh --rebuild-cache"
alias azure-update-subs="/home/pncolvr/Projects/scripts/rofi/web/azure.sh --rebuild-cache"

# need to think how to use these as they are useful shortcuts but not as alias
# alias git-revert-last-commit='git reset --soft HEAD~'
# alias git-clean='git clean -fdx'
# alias gtfo='git remote prune origin'

function config() {
  command git --git-dir="$HOME/.cfg" --work-tree="$HOME" "$@"
}

function _config_git() {
  local -x GIT_DIR="$HOME/.cfg"
  local -x GIT_WORK_TREE="$HOME"
  local -x GIT_OPTIONAL_LOCKS=0
  local service=git
  _git
}

alias gco='git checkout'
if command -v compdef >/dev/null 2>&1; then
    compdef g=git
	  compdef s=ssh
    compdef _git-checkout gco
    compdef _config_git config
fi

function ae () {
  "$SCRIPTS"/files/rename/add-extension.sh
}

# requires sddm-kcm
# requires a lot of packages
# proceed with caution
# function sc () {
#   kcmshell6 kcm_sddm & disown
# }

function cookie-jar () {
  "${XDG_DATA_HOME:-$HOME/.local/share}/qutebrowser/userscripts/cookie-cleaner.sh"
}

# function smaller () {
#   "$SCRIPTS"/media/smaller.sh "$@"
# }

function uc() {
  exec-script "$SCRIPTS/git/sync-projects.sh"
}

function update-gh-token() {
	"$SCRIPTS"/dotnet/update-gh-token.sh "$1"
}

function exec-script() {
  script="$1"
  if [[ ! -x "$script" ]]; then
    chmod +x "$script"
  fi
  eval "$script"
}

# TODO: move to script
# function start-media() {
# 	sudo mergerfs /mnt/hephaestus/media/anime/anime01 /mnt/Media/Anime
# 	sudo mergerfs /mnt/hephaestus/media/movies/movies01:/mnt/hephaestus/media/movies/movies02 /mnt/Media/Movies
# 	sudo mergerfs /mnt/hephaestus/media/shows/shows01:/mnt/hephaestus/media/shows/shows02:/mnt/hephaestus/media/shows/shows03 /mnt/Media/Shows
# }

function birth(){
  stat / | grep "Birth" | sed 's/Birth: //g' | cut -b 2-20
}

function backup-n8n() {
  "$SCRIPTS"/backups/n8n/backup-workflows.sh
}

alias qs-backup='qs ipc call backup create "$PWD/backup-$(date +%Y%m%d).7z"'
function qs-restore() {
  qs ipc call backup restore "${1:A}"
}

function backup() {
  print -P "%F{yellow}Reminder:%f create a Quickshell backup first: %Bqs-backup%b (saves ./backup-YYYYMMDD.7z)"
  sudo ZDOTDIR="$ZDOTDIR" "$SCRIPTS"/backups/host/create.sh backup
}

function backup-browse() {
  "$SCRIPTS"/backups/host/create.sh browse
}

function backup-eject() {
  "$SCRIPTS"/backups/host/create.sh eject
}

# clean-projects [-n] [-y] [dir]: delete build output and dependencies (default dir: ~/Projects)
function clean-projects() {
  "$SCRIPTS"/projects/clean.sh "$@"
}

function update-grub () {
  sudo $SCRIPTS/grub/update.sh "$@"
}

function br () {
  "$SCRIPTS"/brightness/external.sh "$@"
}

function take() {
  mkdir -p "$1"
  cd "$1" || exit
}

function open() {
  __open_with $FILE_BROWSER "$1"
}

function __open_with() {
  local path="."
  if [ "$2" ]; then
    path="$2"
  fi
  "$1" "$path" 1>/dev/null 2>/dev/null & disown
}


function git-change-host() {
    emulate -L zsh
    setopt pipefail

    local new_remote="$1"
    local base_dir="${2:-.}"

    if [[ -z "$new_remote" ]]; then
        echo "Usage: git-change-host <new-hostname> [folder]"
        return 1
    fi

    if [[ "$new_remote" == *[!a-zA-Z0-9.-]* ]]; then
        echo "Invalid hostname: $new_remote"
        return 1
    fi

    local -a repos remotes old_urls new_urls selected
    local repo git_dir remote old_url new_url
    local answer item i count=0 selected_count=0

    echo "Searching Git repositories in: $base_dir"

    while IFS= read -r -d '' git_dir; do
        repo="${git_dir%/.git}"

        while IFS= read -r remote; do
            [[ -z "$remote" ]] && continue

            old_url=$(git -C "$repo" remote get-url "$remote") || continue

            # HTTPS / SSH URLs
            new_url=$(NEW_REMOTE="$new_remote" perl -pe '
                s{^([a-zA-Z][a-zA-Z0-9+.-]*://)(?:([^/@]+)@)?([^/:]+)(:\d+)?(/.*)?$}{
                    $1 . (defined $2 ? "$2@" : "") .
                    $ENV{NEW_REMOTE} .
                    (defined $4 ? $4 : "") .
                    (defined $5 ? $5 : "")
                }e;

                # SCP-style SSH URLs: git@host:path
                if (!m{://}) {
                    s{^([^/@]+)@([^:]+):(.*)$}{
                        "$1@" . $ENV{NEW_REMOTE} . ":$3"
                    }e;
                }
            ' <<< "$old_url")

            [[ "$old_url" == "$new_url" ]] && continue

            (( count++ ))

            repos[$count]="$repo"
            remotes[$count]="$remote"
            old_urls[$count]="$old_url"
            new_urls[$count]="$new_url"
            selected[$count]=1

        done < <(git -C "$repo" remote 2>/dev/null)

    done < <(find "$base_dir" -type d -name .git -prune -print0)

    if (( count == 0 )); then
        echo "No remote URLs need changing."
        return 0
    fi

    # Interactive selection
    while true; do
        echo
        echo "Proposed changes (all selected by default):"
        echo

        selected_count=0

        for (( i=1; i<=count; i++ )); do
            if (( selected[i] )); then
                echo "[$i] [x] ${repos[i]} (${remotes[i]})"
                (( selected_count++ ))
            else
                echo "[$i] [ ] ${repos[i]} (${remotes[i]})"
            fi

            echo "      OLD: ${old_urls[i]}"
            echo "      NEW: ${new_urls[i]}"
            echo
        done

        echo "Selected: $selected_count / $count"
        echo
        echo "Enter numbers to toggle (e.g. 1 3)"
        echo "a = select all | n = select none | q = quit"
        echo "Press ENTER to continue with selection."

        read "answer?Selection: "

        [[ -z "$answer" ]] && break

        case "$answer" in
            q|Q)
                echo "Cancelled. No changes made."
                return 0
                ;;
            a|A)
                for (( i=1; i<=count; i++ )); do
                    selected[$i]=1
                done
                continue
                ;;
            n|N)
                for (( i=1; i<=count; i++ )); do
                    selected[$i]=0
                done
                continue
                ;;
        esac

        for item in ${(z)answer}; do
            if [[ "$item" == <-> ]] &&
               (( item >= 1 && item <= count )); then
                selected[$item]=$(( 1 - selected[$item] ))
            else
                echo "Invalid selection: $item"
            fi
        done
    done

    if (( selected_count == 0 )); then
        echo "Nothing selected. No changes made."
        return 0
    fi

    echo
    echo "About to update $selected_count remote(s)."
    read "answer?Proceed? [y/N] "

    if [[ "$answer" != [yY] ]]; then
        echo "Cancelled. No changes made."
        return 0
    fi

    # Apply selected changes
    echo
    for (( i=1; i<=count; i++ )); do
        (( selected[i] )) || continue

        if git -C "${repos[i]}" remote set-url \
            "${remotes[i]}" "${new_urls[i]}"; then
            echo "Updated: ${repos[i]} (${remotes[i]})"
        else
            echo "ERROR: ${repos[i]} (${remotes[i]})"
        fi
    done

    echo
    echo "Finished."
}


DISABLE_AUTO_TITLE="false"

# shellcheck disable=SC1094
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Give recognized commands the same weight as unknown commands.
ZSH_HIGHLIGHT_STYLES[arg0]='fg=green,bold'

export PATH="$PATH:/home/pncolvr/.local/bin"
export PATH="$HOME/.cargo/bin:$PATH"
export PATH="$PATH:$HOME/.dotnet/tools"

if [ -z "$WAYLAND_DISPLAY" ]; then
	setxkbmap -layout us -variant intl
fi

_nvm_lazy_source() {
  source /usr/share/nvm/init-nvm.sh
}

nvm() {
  unfunction nvm node npm npx
  _nvm_lazy_source
  nvm "$@"
}

node() {
  unfunction nvm node npm npx
  _nvm_lazy_source
  command node "$@"
}

npm() {
  unfunction nvm node npm npx
  _nvm_lazy_source
  command npm "$@"
}

npx() {
  unfunction nvm node npm npx
  _nvm_lazy_source
  command npx "$@"
}

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

autoload -Uz vcs_info
setopt prompt_subst
setopt inc_append_history_time
setopt transient_rprompt   # remove the right prompt after pressing Enter
zmodload zsh/datetime

typeset -g _command_started_at=''
typeset -g _command_line=''
typeset -g _exec_time=''

# first word of commands that should never show a duration
typeset -ga _timer_ignore=(
  clear
  # clear reset cd z ls ll pwd exit fg bg jobs history h
  # nvim vim less man ssh heph-ssh htop btop fzf ff fastfetch open code
)
# only show if it took at least this long, in ms (0 = always show)
typeset -gi _timer_min_ms=0

preexec() {
  _command_started_at=$EPOCHREALTIME
  _command_line=$1
}

function _format_execution_time() {
  local milliseconds=$1
  local seconds minutes hours

  if (( milliseconds < 1000 )); then
    print -r -- "${milliseconds} ms"
  elif (( milliseconds < 60000 )); then
    printf '%d.%03ds\n' "$(( milliseconds / 1000 ))" "$(( milliseconds % 1000 ))"
  elif (( milliseconds < 3600000 )); then
    minutes=$(( milliseconds / 60000 ))
    seconds=$(( milliseconds / 1000 % 60 ))
    print -r -- "${minutes}m ${seconds}s"
  else
    hours=$(( milliseconds / 3600000 ))
    minutes=$(( milliseconds / 60000 % 60 ))
    seconds=$(( milliseconds / 1000 % 60 ))
    print -r -- "${hours}h ${minutes}m ${seconds}s"
  fi
}

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes false
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '!'
zstyle ':vcs_info:git:*' formats ' %F{green}%b%f%c%u'
zstyle ':vcs_info:git:*' actionformats ' %F{green}%b|%a%f%c%u'

precmd() {
  local last_status=$?
  _exec_time=''

  if [[ -n "$_command_started_at" ]]; then
    local -i elapsed_ms=$(( (EPOCHREALTIME - _command_started_at) * 1000 ))
    local -a words=( ${(z)_command_line} )
    [[ ${words[1]} == sudo ]] && shift words
    local cmd=${words[1]}
    _command_started_at=''
    _command_line=''

    if (( elapsed_ms >= _timer_min_ms )) && (( ! ${_timer_ignore[(Ie)$cmd]} )); then
      _exec_time=$(_format_execution_time "$elapsed_ms")
    fi
  fi
  vcs_info

  [[ $PWD == $HOME ]] && PROMPT_PATH='' || PROMPT_PATH='%F{cyan}%~%f'
  [[ -n "$PROMPT_PATH" || -n "$vcs_info_msg_0_" ]] && PROMPT_GAP=' ' || PROMPT_GAP=''
  if (( last_status == 0 )); then
    PROMPT_CHAR='%F{green}❯%f'
  else
    PROMPT_CHAR='%F{red}❯%f'
  fi
}

PROMPT='${PROMPT_PATH}${vcs_info_msg_0_}${PROMPT_GAP}${PROMPT_CHAR} '
RPROMPT='%B%F{8}${_exec_time}%f%b'

eval "$(zoxide init zsh)"
# zprof

# Initialize after global aliases, completions and directory hooks.
source "${${(%):-%x}:A:h}/scripts/shell/project-shell.zsh"