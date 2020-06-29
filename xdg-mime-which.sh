#!/usr/bin/env bash

# Determines where the xdg default application for the given mime type is set,
#
# Credits: option 3 from https://unix.stackexchange.com/a/593508/17409 

set -eu


# For lack of a better way, trace which files `xdg-mime query default` opens
# when queries with the given mimetype.
get_file_list() {
    strace -f -e trace=open,openat,creat xdg-mime query default "${1}" 2>&1 \
    | grep --extended-regexp "(mime(apps|info)?|defaults)\.(list|cache)" \
    | grep -v "ENOENT" \
    | sed -E -e 's/^.*"([^"]*)".*$/\1/'
}

# Check if the given file contains a definition for the given mimetype.
contains_type() {
    grep -qcE "^${2}=" "${1}"
}


# Find the first matching file
for f in $(get_file_list "${1}"); do
    if contains_type "${f}" "${1}"; then
        realpath "${f}"
        exit 0
    fi
done

exit 1
