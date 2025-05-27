#!/usr/bin/env bash

[ ${#} -ge 1 ] && input="${1}" || read -r input

echo "${input}" | sed 's/[^[:alnum:]\.\_]\+/-/g'

