#!/bin/bash
set -euo pipefail

# Run common components
$CI_ROOT/components/git-clone.sh
$CI_ROOT/components/mvn-package.sh
