#!/bin/bash
set -euo pipefail

show_usage() {
  echo "Usage:"
  echo "  ./status.sh [-n <count>] [<project> [<env> [<build_id>]]]"
  echo ""
  echo "Examples:"
  echo "  ./status.sh                      # Show last 5 builds of all projects"
  echo "  ./status.sh -n 10                # Show last 10 builds of all projects"
  echo "  ./status.sh project-a            # Show last 5 builds of project-a"
  echo "  ./status.sh project-a dev        # Show last 5 builds of project-a/dev"
  echo "  ./status.sh project-a dev 5      # Show ONLY build #5 of project-a/dev"
  echo "  ./status.sh -n 10 project-a dev  # Show last 10 builds of project-a/dev"
}

COUNT=5
ARGS=()

# Parse flags and collect positional args
while [[ $# -gt 0 ]]; do
  case "$1" in
    -n) COUNT="$2"; shift 2 ;;
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
      awk -F',' -v id="$BUILD_ID" '$4==id {print}' "$FILE"
    else
      cat "$FILE"
    fi
  done \
  | awk -F',' -v OFS=',' '{ print $1,$2,$3,$4,$5 }' \
  | sort -t',' -k1,1r
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
