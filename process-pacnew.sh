#!/usr/bin/env bash

# Running `pacman -Syu` can leave behind `*.pacnew` files
# when a (config) file changed in the package but also has local changes.
# This script iterates over such files, prompting the user to
# merge their local changes with the proposed updates.
#
# Requires: fd, gum, meld, sudo

MERGE_TOOL=${MERGE_TOOL:-meld}

for pacnew_file in $(fd --glob '*.pacnew' /); do
  gum log --level=info "Checking ${pacnew_file}"
  sudo "${MERGE_TOOL}" "${pacnew_file%.pacnew}" "${pacnew_file}" \
    || gum log --level=warn "meld exited with error on ${pacnew_file}"

  if gum confirm --affirmative="Delete" --negative="Skip" --default=false "Delete '${pacnew_file}'?"; then
    sudo rm "${pacnew_file}" \
      && gum log --level=info "Deleted ${pacnew_file}"
  fi
done
