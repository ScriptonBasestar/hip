#!/usr/bin/env bash
# Hip CLI bash completion script
#
# Installation:
#   Source this file in your ~/.bashrc or ~/.bash_profile:
#     source /path/to/completions/hip.bash
#
#   Or install system-wide (requires sudo):
#     sudo cp completions/hip.bash /etc/bash_completion.d/hip
#
#   Or use bash-completion package location:
#     # On macOS with Homebrew:
#     cp completions/hip.bash $(brew --prefix)/etc/bash_completion.d/hip
#
#     # On Linux:
#     sudo cp completions/hip.bash /usr/share/bash-completion/completions/hip
#
# Usage:
#   After installation, restart your shell or source your rc file:
#     source ~/.bashrc
#
#   Then enjoy tab completion:
#     hip <TAB>           # Shows all available commands
#     hip run <TAB>       # Shows dynamic commands from hip.yml
#     hip ls --<TAB>      # Shows available options

_hip_completion() {
  local cur prev words cword
  _init_completion || return

  # Manifest cache for performance (60 minute TTL)
  local manifest_cache="/tmp/hip-manifest-$USER.json"
  local cache_ttl=60  # minutes

  # Refresh cache if old or missing
  if [[ ! -f "$manifest_cache" ]] || [[ -n $(find "$manifest_cache" -mmin +$cache_ttl 2>/dev/null) ]]; then
    hip manifest -f json > "$manifest_cache" 2>/dev/null || return 0
  fi

  # Require jq for JSON parsing
  if ! command -v jq &> /dev/null; then
    return 0
  fi

  # Top-level command completion
  if [[ $cword -eq 1 ]]; then
    local static_cmds=$(jq -r '.static_commands | keys[]' "$manifest_cache" 2>/dev/null)
    local subcommand_groups=$(jq -r '.subcommand_groups | keys[]' "$manifest_cache" 2>/dev/null)
    local dynamic_cmds=$(jq -r '.dynamic_commands | keys[]' "$manifest_cache" 2>/dev/null)

    COMPREPLY=($(compgen -W "$static_cmds $subcommand_groups $dynamic_cmds" -- "$cur"))
    return 0
  fi

  # Command-specific completion
  local command="${words[1]}"

  case "$command" in
    run)
      # Complete run command options and dynamic commands
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "--explain -e --publish -p --help -h" -- "$cur"))
      else
        local dynamic_cmds=$(jq -r '.dynamic_commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$dynamic_cmds" -- "$cur"))
      fi
      ;;

    ls)
      # Complete ls command options
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "--format -f --detailed -d --help -h" -- "$cur"))
      elif [[ $prev == "--format" ]] || [[ $prev == "-f" ]]; then
        COMPREPLY=($(compgen -W "table json yaml" -- "$cur"))
      fi
      ;;

    manifest)
      # Complete manifest command options
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "--format -f --help -h" -- "$cur"))
      elif [[ $prev == "--format" ]] || [[ $prev == "-f" ]]; then
        COMPREPLY=($(compgen -W "json yaml" -- "$cur"))
      fi
      ;;

    compose)
      # Complete docker compose commands
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "up down build ps logs exec run restart stop rm pull push config" -- "$cur"))
      elif [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "-f --file -p --project-name -d --detach --help" -- "$cur"))
      fi
      ;;

    ktl|kubectl)
      # Complete kubectl commands
      if [[ $cword -eq 2 ]]; then
        COMPREPLY=($(compgen -W "get describe logs exec apply delete port-forward" -- "$cur"))
      elif [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "-n --namespace --help" -- "$cur"))
      fi
      ;;

    provision)
      # Complete provision profiles
      if [[ $cword -eq 2 ]]; then
        local profiles=$(jq -r 'select(.dynamic_commands.provision != null) | .dynamic_commands.provision.subcommands // {} | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "default $profiles" -- "$cur"))
      fi
      ;;

    ssh)
      # Complete ssh subcommands
      if [[ $cword -eq 2 ]]; then
        local ssh_cmds=$(jq -r '.subcommand_groups.ssh.commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$ssh_cmds" -- "$cur"))
      fi
      ;;

    infra)
      # Complete infra subcommands
      if [[ $cword -eq 2 ]]; then
        local infra_cmds=$(jq -r '.subcommand_groups.infra.commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$infra_cmds" -- "$cur"))
      fi
      ;;

    console)
      # Complete console subcommands
      if [[ $cword -eq 2 ]]; then
        local console_cmds=$(jq -r '.subcommand_groups.console.commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$console_cmds" -- "$cur"))
      fi
      ;;

    devcontainer)
      # Complete devcontainer subcommands
      if [[ $cword -eq 2 ]]; then
        local dc_cmds=$(jq -r '.subcommand_groups.devcontainer.commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$dc_cmds" -- "$cur"))
      fi
      ;;

    claude)
      # Complete claude subcommands
      if [[ $cword -eq 2 ]]; then
        local claude_cmds=$(jq -r '.subcommand_groups.claude.commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$claude_cmds" -- "$cur"))
      fi
      ;;

    help)
      # Complete help topics (all available commands)
      if [[ $cword -eq 2 ]]; then
        local all_cmds=$(jq -r '.static_commands | keys[]' "$manifest_cache" 2>/dev/null)
        COMPREPLY=($(compgen -W "$all_cmds run" -- "$cur"))
      fi
      ;;

    migrate)
      # Complete migrate options
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "--to --summary --help -h" -- "$cur"))
      fi
      ;;

    validate)
      # Complete validate options
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "-c --config --help" -- "$cur"))
      elif [[ $prev == "-c" ]] || [[ $prev == "--config" ]]; then
        # Complete YAML files
        COMPREPLY=($(compgen -f -X '!*.yml' -- "$cur"))
      fi
      ;;

    --version|-v|version)
      # No completion needed
      return 0
      ;;

    *)
      # Check if this is a dynamic command with subcommands
      if [[ $cword -eq 2 ]]; then
        local subcommands=$(jq -r --arg cmd "$command" '.dynamic_commands[$cmd].subcommands // {} | keys[]' "$manifest_cache" 2>/dev/null)
        if [[ -n "$subcommands" ]]; then
          COMPREPLY=($(compgen -W "$subcommands" -- "$cur"))
          return 0
        fi
      fi

      # Generic option completion
      if [[ $cur == -* ]]; then
        COMPREPLY=($(compgen -W "--help -h" -- "$cur"))
      fi
      ;;
  esac
}

# Register completion function
complete -F _hip_completion hip
