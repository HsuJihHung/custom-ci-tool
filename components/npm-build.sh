#!/bin/bash
set -exuo pipefail

echo "npm install"
npm install

echo "npm run build"
npm run build