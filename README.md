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

The file based app was published with the commands:
```bash
cd scripts/status
dotnet publish ./timecard.cs --output ./bin
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