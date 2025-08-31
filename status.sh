#!/bin/bash
set -euo pipefail

show_usage() {
  echo "Usage:"
  echo "  ci-tool status [-n <count>] [<project> [<env> [<build_id>]]]"
  echo ""
  echo "Examples:"
  echo "  ci-tool status                      # Show last 5 builds of all projects"
  echo "  ci-tool status -n 10                # Show last 10 builds of all projects"
  echo "  ci-tool status project-a            # Show last 5 builds of project-a"
  echo "  ci-tool status project-a dev        # Show last 5 builds of project-a/dev"
  echo "  ci-tool status project-a dev 5      # Show ONLY build #5 of project-a/dev"
  echo "  ci-tool status -n 10 project-a dev  # Show last 10 builds of project-a/dev"
}

COUNT=5
ARGS=()

# Parse flags and collect positional args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) 
      # missing value?
      if [[ $# -lt 2 ]]; then
        echo "Error: -n requires a count value." >&2
        show_usage; exit 1
      fi
      # numeric? (positive integer)
      if [[ ! "$2" =~ ^[1-9][0-9]*$ ]]; then
        echo "Error: -n expects a positive integer (got: '$2')." >&2
        show_usage; exit 1
      fi
      COUNT="$2"
      shift 2
      ;;
    -h|--help) show_usage; exit 0 ;;
    -*) echo "Unknown option: $1"; show_usage; exit 1 ;;
    *) ARGS+=("$1"); shift ;;
  esac
done

PROJECT="${ARGS[0]:-}"
ENV="${ARGS[1]:-}"
BUILD_ID="${ARGS[2]:-}"

echo "Build History:"

# Collect rows from all files (no per-file tail/tac), filter optional build_id,
# keep first 5 fields, sort globally by timestamp (desc), then limit to COUNT.
ROWS=$(
  find ./builds/history -name "history.csv" | while read -r FILE; do
    [[ -n "$PROJECT" && "$FILE" != *"/$PROJECT/"* ]] && continue
    [[ -n "$ENV" && "$FILE" != *"/$ENV/"* ]] && continue

    if [[ -n "$BUILD_ID" ]]; then
      awk -F',' -v id="$BUILD_ID" '$3==id {print}' "$FILE"
    else
      cat "$FILE"
    fi
  done \
  | awk -F',' -v OFS=',' '{ print $1,$2,$3,$4,$5,$6 }' \
  | sort -t',' -k5,5r
)

# If BUILD_ID is given, don't trim by COUNT; otherwise take top COUNT after global sort.
if [[ -z "$BUILD_ID" ]]; then
  ROWS="$(printf "%s\n" "$ROWS" | head -n "$COUNT")"
fi

# Prepend header and let column align everything together
{
  echo "PROJECT,ENV,BUILD_ID,STATUS,START_TIME,END_TIME"
  printf "%s\n" "$ROWS"
} | column -t -s ','
