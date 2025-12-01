# Hip Shell Completions

Shell completion scripts for Hip CLI, providing intelligent tab completion for all commands, options, and dynamic commands from `hip.yml`.

## Features

- ✅ **Complete command discovery** - All static, dynamic, and subcommand completion
- ✅ **Manifest-powered** - Uses `hip manifest` for up-to-date command information
- ✅ **Performance optimized** - Caches manifest with 60-minute TTL
- ✅ **Context-aware** - Different completions based on command and position
- ✅ **Description support** - Zsh shows command descriptions inline

## Requirements

- **jq** - JSON processor for parsing manifest
  ```bash
  # macOS
  brew install jq

  # Ubuntu/Debian
  sudo apt-get install jq

  # CentOS/RHEL
  sudo yum install jq
  ```

## Installation

### Quick Install (Recommended)

Use the automated installation script:

```bash
# Interactive installation (detects your shell)
./completions/install.sh

# Install for specific shell
./completions/install.sh bash
./completions/install.sh zsh

# System-wide installation (requires sudo)
./completions/install.sh --system

# Uninstall
./completions/install.sh --uninstall
```

### Manual Installation

#### Bash

**Option 1: User-level**

```bash
# Source in your ~/.bashrc or ~/.bash_profile
echo 'source ~/path/to/hip/completions/hip.bash' >> ~/.bashrc
source ~/.bashrc
```

**Option 2: System-wide**

```bash
# macOS with Homebrew
cp completions/hip.bash $(brew --prefix)/etc/bash_completion.d/hip

# Linux
sudo cp completions/hip.bash /etc/bash_completion.d/hip

# Or bash-completion package location
sudo cp completions/hip.bash /usr/share/bash-completion/completions/hip
```

#### Zsh

**Option 1: User-level**

```bash
# Add to your fpath in ~/.zshrc (before compinit)
fpath=(~/path/to/hip/completions $fpath)
autoload -Uz compinit && compinit
```

**Option 2: System-wide**

```bash
# macOS with Homebrew
cp completions/_hip $(brew --prefix)/share/zsh/site-functions/_hip

# Linux
sudo cp completions/_hip /usr/local/share/zsh/site-functions/_hip
```

**Option 3: Oh-My-Zsh**

```bash
# Copy to custom completions directory
mkdir -p ~/.oh-my-zsh/custom/plugins/hip
cp completions/_hip ~/.oh-my-zsh/custom/plugins/hip/_hip

# Add to plugins in ~/.zshrc
plugins=(... hip)
```

After installation, reload your shell:
```bash
# Bash
source ~/.bashrc

# Zsh
exec zsh
# Or force recompile
rm -f ~/.zcompdump && compinit
```

## Usage Examples

### Basic Completion

```bash
hip <TAB>              # Shows all available commands
hip r<TAB>             # Completes to 'run'
hip run <TAB>          # Shows dynamic commands from hip.yml
hip run she<TAB>       # Completes to 'shell'
```

### Option Completion

```bash
hip ls --<TAB>         # Shows: --format, --detailed, --help
hip ls --format <TAB>  # Shows: table, json, yaml
hip manifest -f <TAB>  # Shows: json, yaml
```

### Subcommand Completion

```bash
hip ssh <TAB>          # Shows: up, down, restart, status
hip devcontainer <TAB> # Shows: init, sync, validate, bash, ...
hip provision <TAB>    # Shows available provision profiles
```

### Dynamic Command Completion

```bash
# If hip.yml defines:
# interaction:
#   rails:
#     subcommands:
#       console:
#       server:
#       db:

hip rails <TAB>        # Shows: console, server, db
hip rails db <TAB>     # Shows db subcommands
```

## How It Works

### Manifest Caching

Completions use `hip manifest` to discover available commands:

1. On first completion, runs `hip manifest -f json`
2. Caches result in `/tmp/hip-manifest-$USER.json`
3. Cache expires after 60 minutes
4. Automatically refreshes when stale

This provides fast completion while staying up-to-date with changes to `hip.yml`.

### Performance

- **First completion**: ~200-300ms (manifest generation + cache)
- **Subsequent completions**: ~10-20ms (cached manifest)
- **Cache refresh**: Automatic after 60 minutes

## Completion Coverage

### Static Commands
All built-in Hip commands with their options:
- `version`, `ls`, `compose`, `ktl/kubectl`, `run`, `provision`, `validate`, `manifest`

### Subcommand Groups
All subcommand groups and their commands:
- `ssh`: up, down, restart, status
- `infra`: update, up, down
- `console`: start, inject
- `devcontainer`: init, sync, validate, bash, provision, features, info
- `claude`: setup

### Dynamic Commands
All commands defined in `hip.yml` `interaction:` section:
- Automatically discovered via manifest
- Includes subcommands and nested structures
- Updates when `hip.yml` changes (after cache refresh)

## Troubleshooting

### Completions Not Working

```bash
# Check if jq is installed
which jq

# Check if hip is in PATH
which hip

# Test manifest generation
hip manifest

# Check cache file
cat /tmp/hip-manifest-$USER.json

# Force cache refresh (delete cache)
rm /tmp/hip-manifest-$USER.json
```

### Bash: Command Not Found

```bash
# Ensure bash-completion is installed
# macOS:
brew install bash-completion@2

# Ubuntu/Debian:
sudo apt-get install bash-completion
```

### Zsh: Completions Not Loading

```bash
# Check fpath includes completion directory
echo $fpath

# Verify compinit is called
grep compinit ~/.zshrc

# Rebuild completion cache
rm -f ~/.zcompdump*
autoload -Uz compinit && compinit
```

### Slow Completion

```bash
# Check manifest generation time
time hip manifest > /dev/null

# If slow, check hip.yml complexity
# Consider simplifying or optimizing config
```

## Development

### Testing Completions

#### Bash
```bash
# Source completion script
source completions/hip.bash

# Enable completion debugging
set -x
hip <TAB><TAB>
set +x
```

#### Zsh
```bash
# Load completion
fpath=(./completions $fpath)
autoload -Uz compinit && compinit

# Test completion
hip <TAB>

# Debug completion
zstyle ':completion:*' verbose yes
zstyle ':completion:*:descriptions' format '%B%d%b'
```

### Adding New Commands

Completions automatically discover new commands from `hip manifest`. To add support for specific options:

1. **Bash**: Edit `hip.bash`, add case in command-specific completion
2. **Zsh**: Edit `_hip`, add arguments in command case

Example (bash):
```bash
mycommand)
  if [[ $cur == -* ]]; then
    COMPREPLY=($(compgen -W "--option1 --option2" -- "$cur"))
  fi
  ;;
```

Example (zsh):
```zsh
mycommand)
  _arguments \
    '(-o --option1)'{-o,--option1}'[Description]:value:' \
    '--option2[Another option]'
  ;;
```

## See Also

- [Hip Documentation](../README.md)
- [LLM Integration Example](../examples/llm-integration.yml)
- [Command Registry](../lib/hip/command_registry.rb)
- [Bash Completion Guide](https://github.com/scop/bash-completion)
- [Zsh Completion System](http://zsh.sourceforge.net/Doc/Release/Completion-System.html)
