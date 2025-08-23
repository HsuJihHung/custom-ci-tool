#!/bin/bash

increment_build_number() {
  local dir="$1"
  local file="$dir/build.number"
  if [[ ! -f "$file" ]]; then
    echo "0" > "$file"
  fi
  local num=$(<"$file")
  local next=$((num + 1))
  echo "$next" > "$file"
  echo "$next"
}

validate_required_config() {
  local config_file="$1"
  local missing=()

  for var in "${CI_REQUIRED_CONFIG_KEYS[@]}"; do
    if [[ -z "${!var:-}" ]]; then
      missing+=("$var")
    fi
  done

  if (( ${#missing[@]} > 0 )); then
    echo "Missing required config variables in $config_file:"
    for var in "${missing[@]}"; do
      echo "   - $var"
    done
    exit 1
  fi
}

append_history() {
  echo "$1,$2,$3,$4,$5" >> "$CI_HISTORY_FILE"
}

update_status() {
  local id="$1"
  local status="$2"
  local tmpfile
  tmpfile=$(mktemp)
  awk -F',' -v OFS=',' -v id="$id" -v status="$status" '
    $4 == id { $5 = status } { print }
  ' "$CI_HISTORY_FILE" > "$tmpfile"
  mv "$tmpfile" "$CI_HISTORY_FILE"
}

parse_build_args() {
  if [[ $# -gt 0 ]]; then
  echo "All args: $@"
  fi
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --sdk)
        BUILD_SDK=true
        shift
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
  done
  # Export them so caller can access
  export BUILD_SDK="${BUILD_SDK:-false}"
}
