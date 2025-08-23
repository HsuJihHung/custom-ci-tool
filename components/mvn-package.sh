#!/bin/bash
set -exuo pipefail

pwd
cd $POM_PATH
mvn clean package -DskipTests