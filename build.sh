#!/bin/bash
set -eEuo pipefail

# === Usage help ===
show_help() {
  cat <<EOF
Usage: build.sh <project> <env> [--additional-args]

Required:
  <project>   Project name (must exist under projects/)
  <env>       Environment name (must exist under the project)

Examples:
  build.sh project-a dev
  build.sh my-app staging --my-custom-param

Note:
  This script is normally called via: ci-tool build ...
EOF
}

# === Parse args ===
if [[ $# -lt 1 || "$1" == "-h" || "$1" == "--help" ]]; then
  show_help
  exit 0
fi

# === INIT ===
CI_ROOT="$(cd "$(dirname "$0")" && pwd)"
export CI_ROOT

PROJECT=${1:-}
ENV=${2:-}

if [[ -z "$PROJECT" || -z "$ENV" ]]; then
  echo "Missing required arguments: <project> and <env>"
  show_help
  exit 1
fi
shift 2 # Remove first two args

CONF_DIR="$CI_ROOT/projects/$PROJECT/$ENV"
CONF_FILE="$CONF_DIR/build.conf"
PIPELINE="$CONF_DIR/pipeline.sh"

if [[ ! -f "$CONF_FILE" ]]; then
  echo "Config not found: $CONF_FILE"
  exit 1
fi
if [[ ! -x "$PIPELINE" ]]; then
  echo "Pipeline not found or not executable: $PIPELINE"
  exit 1
fi

source "$CI_ROOT/common/functions.sh"

parse_build_args "$@" # Parse build arguments

# === SETUP ===

## Retrieve new build number
BUILD_ID=$(increment_build_number "$CONF_DIR")
echo "Build ID: $BUILD_ID"  # Print build id 

## create and cd to workdir
export WORK_DIR="$CI_ROOT/workdir/$PROJECT/$ENV/$BUILD_ID"
mkdir -p "$WORK_DIR"
cd $WORK_DIR

## Define log file
LOG_DIR="$CI_ROOT/builds/logs/$PROJECT/$ENV"
export CI_HISTORY_FILE="$CI_ROOT/builds/history/$PROJECT/$ENV/history.csv"

# run script in background
(
  set -euo pipefail

  cleanup() {
    if [[ -d "$WORK_DIR" ]]; then
      echo "Cleaning up working directory: $WORK_DIR"
      rm -rf "$WORK_DIR"
    fi
  }

  run_pipeline() {
    set -euo pipefail

    # Export config variables
    set -a
    source "$CONF_FILE"
    set +a

    mkdir -p "$LOG_DIR" "$(dirname "$CI_HISTORY_FILE")"
    LOG_FILE="$LOG_DIR/build-$BUILD_ID.log"
    exec >> "$LOG_FILE" 2>&1

    STATUS="RUNNING"
    START_TIME=$(current_time)
    append_history "$PROJECT" "$ENV" "$BUILD_ID" "$STATUS" "$START_TIME"

    echo "Starting build $BUILD_ID for $PROJECT [$ENV]"

    # This is where failure can occur
    "$PIPELINE"
  }

  if run_pipeline; then
    echo "Build $BUILD_ID succeeded"
    update_status "$BUILD_ID" "SUCCESS"
    cleanup
  else
    echo "Build $BUILD_ID failed"
    update_status "$BUILD_ID" "FAILURE"
    cleanup
    exit 1
  fi
) </dev/null &