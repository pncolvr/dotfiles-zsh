autoload -Uz compinit
zmodload zsh/complist
autoload -U run-help

if [[ -n ${ZDOTDIR:-$HOME}/.zcompdump(#qN.mh+24) ]]; then
  compinit
else
  compinit -C
fi

source "${(%):-%x}.env"

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

alias ls="eza -l --group-directories-first --time-style=long-iso --git --no-permissions --no-user"
alias ll='\ls -la'

alias extract='eval $SCRIPTS/archives/extract.sh'
alias archive='eval $SCRIPTS/archives/create.sh -t'

alias bios='systemctl reboot --firmware-setup'

alias reload-zsh='source ~/.config/zsh/.zshrc'
alias edit-zsh='code ~/.config/zsh/.zshrc'

alias nas='cd $NAS_FOLDER'

alias bazecore-update='$SCRIPTS/bazecor/update.sh'

alias cd='z'

alias ff='fastfetch'
alias neofetch='fastfetch'

alias updatemirrors='rate-mirrors arch --max-delay=3600 | sudo tee /etc/pacman.d/mirrorlist && eos-rankmirrors'
alias b='cat $HOME/.config/hypr/config.d/keybindings.conf | grep "^bind" | grep --invert-match "#" | fzf'

function h {
  local value
  value="$(_pick_history_entry)"
  value="${value%$'\n'}"
  [[ -z "$value" ]] && return 0
  wl-copy "$value"
}

alias clear="clear && printf '\e[3J'"
alias testmic="arecord -f cd | aplay"

alias browser='$SCRIPTS/default-browser/default-browser.sh'

alias heph-ssh='ssh pncolvr@$HEPHAESTUS_IP'
alias heph-ping='ping $HEPHAESTUS_IP'

# alias dotnet-update-rid='sudo pwsh -Command $SCRIPTS/dotnet/update-dotnet-endeavouros.ps1'

alias zathura-update-books="$HOME/.config/hypr/scripts/filebrowser/books-pick.sh --rebuild-cache"
alias azure-update-subs="/home/pncolvr/Projects/scripts/rofi/web/azure.sh --rebuild-cache"

# need to think how to use these as they are useful shortcuts but not as alias
# alias git-revert-last-commit='git reset --soft HEAD~'
# alias git-clean='git clean -fdx'
# alias gtfo='git remote prune origin'

function timecard() {
  $ZDOTDIR/scripts/status/bin/timecard -f "$TIMETABLE_FILE" -d "$(date '+%Y-%m-%d')"
}

function timecard-all() {
  $ZDOTDIR/scripts/status/bin/timecard -f "$TIMETABLE_FILE"
}

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
  "$HOME"/.config/qutebrowser/scripts/cookie-cleaner.sh
}

function smaller () {
  if [ -z "$1" ]; then
    echo "Usage: $0 <input_file>"
    exit 1
  fi

  INPUT="$1"
  BASENAME=$(basename "$INPUT")
  NAME="${BASENAME%.*}"

  echo "Choose output resolution [default: 2]:"
  echo "1) 720p"
  echo "2) 1080p"
  
  local RES_CHOICE
  read -r "RES_CHOICE?Enter 1 or 2: " < /dev/tty
  RES_CHOICE=${RES_CHOICE:-2}

  if [ "$RES_CHOICE" = "1" ]; then
    HEIGHT=720
  elif [ "$RES_CHOICE" = "2" ]; then
    HEIGHT=1080
  else
    echo "Invalid choice. Exiting."
    exit 1
  fi

  OUTPUT="${NAME}_${HEIGHT}p30.mp4"

  ffmpeg -i "$INPUT" -vf "scale=-2:${HEIGHT},fps=30" \
    -c:v h264_nvenc -preset fast -rc:v vbr_hq -cq:v 19 -b:v 0 \
    -c:a aac -b:a 128k "$OUTPUT"

  echo "Conversion complete: $OUTPUT"
}

function zip-with-password () {
  7z a -tzip -p"$1" -mem=AES256 "$1"
}

# TODO: refactor so we can have several folders
function sw() {
  "$HOME"/.config/hypr/scripts/wallpapers/picker.sh "$HOME"/Pictures/wallpapers/
}

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

function backup() {
  sudo ZDOTDIR="$ZDOTDIR" "$SCRIPTS"/backups/host/create.sh backup
}

function code-update-projects () {
  $SCRIPTS/code/update-projects.sh
}

function update-grub () {
  sudo $SCRIPTS/grub/update.sh "$@"
}

function g () {
    git "$@" || exit 1
    
    local repoFolder=""
    
    case "$1" in
        clone)
            local lastArg="${!#}"
            if [[ ! "$lastArg" =~ ^- ]] && [[ $# -ge 3 ]]; then
                repoFolder=$(realpath "$lastArg")
            else
                for arg in "$@"; do
                    if [[ "$arg" =~ (https?://|git@|\.git$) ]]; then
                        local repoName=$(basename "$arg" .git)
                        repoFolder=$(realpath "$repoName")
                        break
                    fi
                done
            fi
            ;;
        init)
            local lastArg="${!#}"
            if [[ ! "$lastArg" =~ ^- ]] && [[ $# -ge 2 ]]; then
                repoFolder=$(realpath "$lastArg")
            else
                repoFolder=$(realpath ".")
            fi
            ;;
    esac
    
    __update_projects "$repoFolder"
}

function __update_projects () {
    local p="$1"
    
    [[ -z "$p" ]] && return
    
    local shouldUpdate=false
    
    if [[ "$p" == $WORK_REPOS_PATH/* ]]; then
        shouldUpdate=true
    else
        read "REPLY?Add '$p' to projects.txt? (Y/n): "
        
        [[ -z "$REPLY" ]] && REPLY="y"
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            if ! grep -Fxq "$p" "$additionalProjectsFilePath"; then
                echo "$p" >> "$additionalProjectsFilePath"
                echo "Added $p to projects.txt"
                shouldUpdate=true
            else
                echo "$p is already in projects.txt"
            fi
        fi
    fi
    
    if [[ "$shouldUpdate" == true ]]; then
       code-update-projects-silent
    fi
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

DISABLE_AUTO_TITLE="false"

# shellcheck disable=SC1094
source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

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

eval "$(zoxide init zsh)"

zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

autoload -Uz vcs_info
setopt prompt_subst
setopt inc_append_history_time

zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' check-for-changes false
zstyle ':vcs_info:git:*' stagedstr '+'
zstyle ':vcs_info:git:*' unstagedstr '!'
zstyle ':vcs_info:git:*' formats ' %F{76}%b%f%c%u'
zstyle ':vcs_info:git:*' actionformats ' %F{76}%b|%a%f%c%u'

precmd() {
  local last_status=$?
  
  vcs_info

  [[ $PWD == $HOME ]] && PROMPT_PATH='' || PROMPT_PATH='%F{31}%~%f'
  [[ -n "$PROMPT_PATH" || -n "$vcs_info_msg_0_" ]] && PROMPT_GAP=' ' || PROMPT_GAP=''
  if (( last_status == 0 )); then
    PROMPT_CHAR='%F{76}❯%f'
  else
    PROMPT_CHAR='%F{196}❯%f'
  fi
}

PROMPT='${PROMPT_PATH}${vcs_info_msg_0_}${PROMPT_GAP}${PROMPT_CHAR} '

