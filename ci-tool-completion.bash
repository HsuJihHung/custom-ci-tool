# Auto-completion for ci-tool

_ci_tool_completions() {
  local cur prev
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"

  # Resolve CI_ROOT from real path of ci-tool
  local ci_tool_path CI_ROOT
  ci_tool_path="$(readlink -f "$(command -v ci-tool)")"
  CI_ROOT="$(cd "$(dirname "$ci_tool_path")" && pwd)"

  local commands="build status logs help"
  local cmd="${COMP_WORDS[1]:-}"

  # Show top-level commands
  if [[ $COMP_CWORD -eq 1 ]]; then
    COMPREPLY=( $(compgen -W "$commands" -- "$cur") )
    return
  fi

  # Define flags for each command
  local status_flags="-n -h --help"
  local logs_flags="-f -h --help"

  # Collect all positional (non-flag) args starting from index 2
  local positional=()
  for ((i = 2; i < COMP_CWORD; i++)); do
    [[ "${COMP_WORDS[i]}" != -* ]] && positional+=("${COMP_WORDS[i]}")
  done

  local arg1="${positional[0]:-}"  # project
  local arg2="${positional[1]:-}"  # env
  local arg3="${positional[2]:-}"  # build ID

  case "$cmd" in
    build)
      if [[ ${#positional[@]} -eq 0 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects" 2>/dev/null)" -- "$cur") )
      elif [[ ${#positional[@]} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects/$arg1" 2>/dev/null)" -- "$cur") )
      fi
      ;;

    status)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$status_flags" -- "$cur") )
        return
      fi

      if [[ ${#positional[@]} -eq 0 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects" 2>/dev/null)" -- "$cur") )
      elif [[ ${#positional[@]} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects/$arg1" 2>/dev/null)" -- "$cur") )
      elif [[ ${#positional[@]} -eq 2 ]]; then
        local builds_dir="$CI_ROOT/builds/logs/$arg1/$arg2"
        local builds=$(ls "$builds_dir" 2>/dev/null | sed -n 's/build-\([0-9]\+\)\.log/\1/p')
        COMPREPLY=( $(compgen -W "$builds" -- "$cur") )
      fi
      ;;

    logs)
      if [[ "$cur" == -* ]]; then
        COMPREPLY=( $(compgen -W "$logs_flags" -- "$cur") )
        return
      fi

      if [[ ${#positional[@]} -eq 0 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects" 2>/dev/null)" -- "$cur") )
      elif [[ ${#positional[@]} -eq 1 ]]; then
        COMPREPLY=( $(compgen -W "$(ls "$CI_ROOT/projects/$arg1" 2>/dev/null)" -- "$cur") )
      elif [[ ${#positional[@]} -eq 2 ]]; then
        local builds_dir="$CI_ROOT/builds/logs/$arg1/$arg2"
        local builds=$(ls "$builds_dir" 2>/dev/null | sed -n 's/build-\([0-9]\+\)\.log/\1/p')
        COMPREPLY=( $(compgen -W "$builds" -- "$cur") )
      fi
      ;;
  esac
}

# Register completion function
complete -F _ci_tool_completions ci-tool