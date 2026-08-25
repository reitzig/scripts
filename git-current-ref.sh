#!/usr/bin/env bash

set -euo pipefail

# Credits: https://stackoverflow.com/a/64886613
git symbolic-ref --short -q HEAD \
  || git describe --tags --exact-match 2> /dev/null \
  || git rev-parse --short HEAD
