#!/usr/bin/env bash
set -euo pipefail

show_usage() {
  cat <<'USAGE'
Usage:
  ci-tool clear [-n <keep_count>] [-y] [-h] <project> <env>

Options:
  -n <keep_count>   Keep the last N rows in history.csv and matching logs. Default: 0 (delete all).
  -y                Yes to all confirmations (non-interactive).
  -h, --help        Show this help.

Examples:
  ci-tool clear demo-project dev -n 5 -y
  ci-tool clear -y demo-project -n 3 dev
  ci-tool clear -h
USAGE
}

# -------- Defaults --------
KEEP=0
YES=0
ARGS=()

# -------- Order-agnostic arg parser --------
if [[ $# -eq 0 ]]; then show_usage; exit 1; fi

while (( $# )); do
  case "$1" in
    -n)
      if (( $# < 2 )); then
        echo "Error: -n requires a value." >&2; show_usage; exit 1
      fi
      if [[ ! "$2" =~ ^[0-9]+$ ]]; then
        echo "Error: -n expects a non-negative integer (got: '$2')." >&2
        show_usage; exit 1
      fi
      KEEP="$2"; shift 2
      ;;
    -y)
      YES=1; shift
      ;;
    -h|--help)
      show_usage; exit 0
      ;;
    --)
      shift
      while (( $# )); do ARGS+=("$1"); shift; done
      ;;
    -*)
      echo "Unknown option: $1" >&2; show_usage; exit 1
      ;;
    *)
      ARGS+=("$1"); shift
      ;;
  esac
done

# -------- Positionals --------
PROJECT="${ARGS[0]:-}"; ENV="${ARGS[1]:-}"
if [[ -z "$PROJECT" || -z "$ENV" ]]; then
  echo "Error: <project> and <env> are required." >&2
  show_usage; exit 1
fi

# -------- Paths --------
HISTORY_DIR="./builds/history/$PROJECT/$ENV"
LOGS_DIR="./builds/logs/$PROJECT/$ENV"
HISTORY_FILE="$HISTORY_DIR/history.csv"

# -------- Helpers --------
confirm() {
  local msg="$1"
  if (( YES )); then return 0; fi
  read -r -p "$msg [y/N] " reply || true
  [[ "$reply" == "y" || "$reply" == "Y" ]]
}

# Extract last N BUILD_IDs from history.csv (no header, BUILD_ID is col 3)
build_ids_to_keep_from_history() {
  local n="$1"
  [[ -f "$HISTORY_FILE" && "$n" -gt 0 ]] || return 0
  tail -n "$n" "$HISTORY_FILE" 2>/dev/null | awk -F',' 'NF{gsub(/^[ \t]+|[ \t]+$/,"",$3); print $3}'
}

# Fallback: newest N log files by mtime
log_files_to_keep_by_mtime() {
  ls -1t "$LOGS_DIR"/build-*.log 2>/dev/null | head -n "$KEEP" || true
}

# Safety: refuse suspicious paths
for p in "$HISTORY_DIR" "$LOGS_DIR"; do
  if [[ -n "$p" ]]; then
    case "$p" in
      "."|"/"|"./"|"/."|"/.."|"../") echo "Safety abort: suspicious path '$p'." >&2; exit 1 ;;
    esac
  fi
done

echo "Cleaning project=$PROJECT env=$ENV (keep=$KEEP, yes=$YES)"
if [[ ! -d "$HISTORY_DIR" && ! -d "$LOGS_DIR" ]]; then
  echo "Nothing to do: no such project/env under builds/. Checked:"
  echo "  $HISTORY_DIR"
  echo "  $LOGS_DIR"
  exit 0
fi

# -------- HISTORY CLEANUP (no backups) --------
if [[ -f "$HISTORY_FILE" ]]; then
  if (( KEEP == 0 )); then
    if confirm "Delete ALL history at $HISTORY_FILE ?"; then
      rm -f -- "$HISTORY_FILE"
      echo "History removed: $HISTORY_FILE"
    else
      echo "Skipped history deletion."
    fi
  else
    if confirm "Truncate history to last $KEEP entries at $HISTORY_FILE ?"; then
      tmp="$(mktemp)"
      tail -n "$KEEP" "$HISTORY_FILE" > "$tmp"
      mv "$tmp" "$HISTORY_FILE"
      echo "History truncated to $KEEP entries."
    else
      echo "Skipped history truncation."
    fi
  fi
else
  echo "No history file at $HISTORY_FILE"
fi

# -------- Determine build IDs to keep (after any truncation) --------
declare -A KEEP_IDS=()
if (( KEEP > 0 )); then
  mapfile -t ids < <(build_ids_to_keep_from_history "$KEEP" || true)
  for id in "${ids[@]:-}"; do
    [[ -n "$id" ]] && KEEP_IDS["$id"]=1
  done
fi

# -------- LOGS CLEANUP --------
if [[ -d "$LOGS_DIR" ]]; then
  shopt -s nullglob
  logs=( "$LOGS_DIR"/build-*.log )
  shopt -u nullglob

  if (( ${#logs[@]} == 0 )); then
    echo "No logs found in $LOGS_DIR"
  else
    if (( KEEP == 0 )); then
      if confirm "Delete ALL logs in $LOGS_DIR ?"; then
        rm -f -- "$LOGS_DIR"/build-*.log
        echo "All logs removed in $LOGS_DIR"
      else
        echo "Skipped log deletion."
      fi
    else
      # If we couldn't derive IDs (no/short history), fallback to newest N by mtime
      mapfile -t keep_logs_mtime < <( (( ${#KEEP_IDS[@]} == 0 )) && log_files_to_keep_by_mtime || true )

      to_delete=()
      to_keep=()
      for f in "${logs[@]}"; do
        base="$(basename "$f")"        # build-123.log
        id="${base#build-}"; id="${id%.log}"
        keep_this=0
        if (( ${#KEEP_IDS[@]} > 0 )) && [[ "${KEEP_IDS[$id]+x}" == "x" ]]; then
          keep_this=1
        elif (( ${#keep_logs_mtime[@]} > 0 )); then
          for kf in "${keep_logs_mtime[@]}"; do
            if [[ "$kf" == "$f" ]]; then keep_this=1; break; fi
          done
        fi
        if (( keep_this == 1 )); then
          to_keep+=( "$f" )
        else
          to_delete+=( "$f" )
        fi
      done

      echo "Will keep ${#to_keep[@]} log(s)."
      for k in "${to_keep[@]}"; do echo " keep: $k"; done

      if (( ${#to_delete[@]} > 0 )); then
        if confirm "Delete ${#to_delete[@]} other log(s) in $LOGS_DIR ?"; then
          rm -f -- "${to_delete[@]}"
          echo "Removed ${#to_delete[@]} log(s)."
        else
          echo "Skipped deleting logs."
        fi
      else
        echo "No logs to delete."
      fi
    fi

    # Remove empty dirs (leafs)
    find "$LOGS_DIR" -type d -empty -delete || true
  fi
else
  echo "No logs directory at $LOGS_DIR"
fi

# -------- Remove empty history dirs too --------
find "$HISTORY_DIR" -type d -empty -delete 2>/dev/null || true

echo "Done."
