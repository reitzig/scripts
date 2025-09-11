#!/usr/bin/env bash

set -euo pipefail

{ [ ${#} -ge 1 ] && input="${1}"; } \
    || read -r input

# NB:
#  - set locale to C so that umlauts aren't matched by `a-z`;
#     see also https://unix.stackexchange.com/q/390454
#  - first sed script replaces illegal characters
#  - second one lower-cases the whole thing
# shellcheck disable=SC2001
echo "${input}" | LC_ALL=C sed -e 's/[^a-zA-Z0-9\.\_]\+/-/g' -e 's/\(.*\)/\L\1/'

