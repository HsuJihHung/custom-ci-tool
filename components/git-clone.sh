#!/bin/bash
set -exuo pipefail

echo "Cloning $GIT_REPO Branch $GIT_BRANCH"
git clone --branch "$GIT_BRANCH" --single-branch "$GIT_REPO"
echo "Current commit: $(git log -1 --no-merges --oneline)"
