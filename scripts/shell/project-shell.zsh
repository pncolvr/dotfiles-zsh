# Folder-scoped helpers for explicitly registered, trusted project roots.
zmodload zsh/parameter || return
autoload -Uz add-zsh-hook
(( $+functions[_project_shell_unload] )) && _project_shell_unload

typeset -gA _project_shell_before=() _project_shell_snapshot=() _project_shell_saved=()
typeset -ga _project_shell_changes=()
typeset -g _project_shell_active_root='' _project_shell_active_script='' _project_shell_busy=0

_project_shell_capture() {
  emulate -L zsh
  local _project_shell_table _project_shell_name _project_shell_attributes _project_shell_key
  local -A _project_shell_entries
  _project_shell_snapshot=()
  for _project_shell_table in functions aliases galiases saliases _comps _services _patcomps _postpatcomps; do
    (( ${+parameters[$_project_shell_table]} )) || continue
    _project_shell_entries=( "${(@kvP)_project_shell_table}" )
    for _project_shell_name in "${(@k)_project_shell_entries}"; do
      _project_shell_key=$_project_shell_table:$_project_shell_name
      _project_shell_snapshot[$_project_shell_key]=$_project_shell_entries[$_project_shell_name]
    done
  done
  for _project_shell_name in "${(@k)parameters}"; do
    case $_project_shell_name in
      _project_shell_*|_comps|_services|_patcomps|_postpatcomps) continue ;;
      path|fpath) ;;
      *)
        _project_shell_attributes=$parameters[$_project_shell_name]
        case $_project_shell_attributes in
          *readonly*|*special*|*local*) continue ;;
        esac
        ;;
    esac
    _project_shell_key=parameters:$_project_shell_name
    _project_shell_snapshot[$_project_shell_key]=$(typeset -p "$_project_shell_name")
  done
}

_project_shell_unload() {
  emulate -L zsh
  local _project_shell_key _project_shell_table _project_shell_name
  for _project_shell_key in "${_project_shell_changes[@]}"; do
    _project_shell_table=${_project_shell_key%%:*}
    _project_shell_name=${_project_shell_key#*:}
    case $_project_shell_table in
      parameters)
        # Normal parameters can change type; tied search paths retain their tie.
        case $_project_shell_name in
          path|fpath) ;;
          *) unset "$_project_shell_name" ;;
        esac
        if (( ${+_project_shell_saved[$_project_shell_key]} )); then
          # typeset -p supplies shell-quoted declarations, never raw values.
          eval "$_project_shell_saved[$_project_shell_key]"
        fi
        ;;
      *)
        if (( ${+_project_shell_saved[$_project_shell_key]} )); then
          typeset -g "${_project_shell_table}[${_project_shell_name}]=${_project_shell_saved[$_project_shell_key]}"
        else
          unset "${_project_shell_table}[${_project_shell_name}]"
        fi
        ;;
    esac
  done
  _project_shell_saved=()
  _project_shell_changes=()
  _project_shell_before=()
  _project_shell_snapshot=()
  _project_shell_active_root=''
  _project_shell_active_script=''
}

_project_shell_sync() {
  emulate -L zsh
  (( _project_shell_busy )) && return 0
  local _project_shell_directory=${PWD:A}
  local _project_shell_root _project_shell_candidate _project_shell_script=''
  local _project_shell_selected='' _project_shell_key _project_shell_result
  local -a _project_shell_keys
  for _project_shell_root in "${(@k)PROJECT_SHELLS}"; do
    _project_shell_candidate=${_project_shell_root:A}
    [[ $_project_shell_directory == "$_project_shell_candidate" || $_project_shell_directory == "$_project_shell_candidate/"* ]] || continue
    (( ${#_project_shell_candidate} > ${#_project_shell_selected} )) || continue
    [[ -r ${PROJECT_SHELLS[$_project_shell_root]} ]] || continue
    _project_shell_selected=$_project_shell_candidate
    _project_shell_script=${PROJECT_SHELLS[$_project_shell_root]:A}
  done
  [[ $_project_shell_selected == $_project_shell_active_root && $_project_shell_script == $_project_shell_active_script ]] && return 0
  _project_shell_busy=1
  _project_shell_unload
  if [[ -z $_project_shell_selected ]]; then
    _project_shell_busy=0
    return 0
  fi
  _project_shell_capture
  _project_shell_before=( "${(@kv)_project_shell_snapshot}" )
  _project_shell_active_root=$_project_shell_selected
  _project_shell_active_script=$_project_shell_script
  source "$_project_shell_script"
  _project_shell_result=$?
  _project_shell_capture
  _project_shell_keys=( "${(@k)_project_shell_before}" "${(@k)_project_shell_snapshot}" )
  for _project_shell_key in "${(@u)_project_shell_keys}"; do
    if (( ${+_project_shell_before[$_project_shell_key]} == ${+_project_shell_snapshot[$_project_shell_key]} )) \
      && [[ $_project_shell_before[$_project_shell_key] == $_project_shell_snapshot[$_project_shell_key] ]]; then
      continue
    fi
    _project_shell_changes+=( "$_project_shell_key" )
    if (( ${+_project_shell_before[$_project_shell_key]} )); then
      _project_shell_saved[$_project_shell_key]=$_project_shell_before[$_project_shell_key]
    fi
  done
  _project_shell_before=()
  _project_shell_snapshot=()
  if (( _project_shell_result )); then
    _project_shell_unload
    print -u2 -- 'Project shell helper failed; shell changes were restored.'
  fi
  _project_shell_busy=0
}

add-zsh-hook chpwd _project_shell_sync
_project_shell_sync
