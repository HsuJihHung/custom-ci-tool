#!/bin/bash
set -euo pipefail

# === Usage ===
usage() {
  echo "Usage: ci-tool logs [-f] <project> <env> <build_id>"
  echo ""
  echo "Options:"
  echo "  -f        Tail the log output (like tail -f)"
  echo ""
  echo "Example:"
  echo "  ci-tool logs project-a dev 7"
  echo "  ci-tool logs -f project-a dev 8"
  exit 1
}

# === Parse args ===
FOLLOW=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -f)
      FOLLOW=true
      shift
      ;;
    -h|--help)
      usage
      ;;
    -*)
      echo "Unknown option: $1"
      usage
      ;;
    *)
      if [[ -z "${PROJECT:-}" ]]; then
        PROJECT="$1"
      elif [[ -z "${ENV:-}" ]]; then
        ENV="$1"
      elif [[ -z "${BUILD_ID:-}" ]]; then
        BUILD_ID="$1"
      else
        echo "❌ Too many arguments."
        usage
      fi
      shift
      ;;
  esac
done

# === Validate ===
if [[ -z "${PROJECT:-}" || -z "${ENV:-}" || -z "${BUILD_ID:-}" ]]; then
  echo "Missing required arguments."
  usage
fi

# === Resolve path ===
CI_ROOT="$(cd "$(dirname "$0")" && pwd)"
LOG_FILE="$CI_ROOT/builds/logs/$PROJECT/$ENV/build-$BUILD_ID.log"

if [[ ! -f "$LOG_FILE" ]]; then
  echo "Log file not found: $LOG_FILE"
  exit 1
fi

# === Display ===
if $FOLLOW; then
  tail -f "$LOG_FILE"
else
  echo ""
  cat "$LOG_FILE"
fi