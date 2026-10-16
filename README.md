# Info

This is my personal daily driver zsh configuration.

# Setup
On my home directory I have a .zshenv file with the following content:
```
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:=$HOME/.config}"
export ZDOTDIR="${ZDOTDIR:=$XDG_CONFIG_HOME/zsh}"

source "$ZDOTDIR/.zshenv"
```
I also have .zshrc file, which is a symbolic link that points to 
```
$ZDOTDIR/.zshrc
```

# Relevant Commands
I use this repo as a git submodule on my dotfiles.  
The following command is isued on the dotfiles repo, to have this one as a submodule.
```shell
git submodule add git@github.com:pncolvr/dotfiles-zsh.git .config/zsh
```

## When cloning a "parent repo" to include the submodules

```shell
git clone --recurse-submodules <repository-url>
```
_or_ if we cloned the repo without the submodules
```shell
git submodule update --init --recursive
```

# Syncing submodules

```shell
git submodule sync --recursive
```

# Project shell helpers

The shared loader in `scripts/shell/project-shell.zsh` activates helpers only
inside explicitly registered project folders and their descendants. Register
trusted helpers in the optional, ignored `.zshrc.env` file:

```zsh
typeset -gA PROJECT_SHELLS=(
  "$HOME/Projects/example" "$HOME/Projects/example/.zsh/project.zsh"
)
```

Add or remove folder/helper pairs to enable different functionality in different
locations. Each helper can group its own commands, aliases, variables, tool paths
and completions. The loader contains no project-specific behavior. Run
`reload-zsh` after editing the mapping; changing folders then applies the registered
helpers automatically.

It works when a terminal starts inside the project (including VS Code terminals),
on directory changes and through symlinks. The most specific registered folder
wins. Leaving restores functions, ordinary/global/suffix aliases, ordinary global
variables, PATH/fpath and completion bindings changed by the helper. Unrelated
shell additions are preserved. Reloading `.zshrc` unloads before rebuilding the
global configuration, then reapplies the current project's helper with one hook.
Missing private configuration or helper files are optional. A failed helper
restores its shell changes and reports the failure without preventing `cd`.

Helpers should declare commands and setup state; external actions performed while
sourcing cannot be undone. Use `typeset -g` for typed global declarations. Register
completion functions with `autoload -Uz` and `compdef`; completion initialization
already belongs to the main shell configuration. State is kept in memory.

Run `zsh -f tests/project-shell.zsh` to exercise synthetic projects, state cleanup,
cached completions, nested/symlink paths, switching, rollback and actual shell
startup/reload with missing or present private configuration. The tests isolate
HOME and configuration and mock startup desktop tools; no real project helper is
sourced and no desktop actions run.
