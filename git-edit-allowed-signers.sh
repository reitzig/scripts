#!/usr/bin/env bash

set -euo pipefail

allowed_signers_file="$(pwd)/.git/info/allowed_signers"
editor="${EDITOR:-vi}"

git status > /dev/null # aborts if current dir isn't a Git repo

# TODO: if a different file is already configured, ask whether to overwrite or use that one

if [[ ! -e "${allowed_signers_file}" ]]; then
  cat <<TXT > "${allowed_signers_file}"
# List of known email-key pairs
# Format: one line per pair, each
#   <email> <public-key>
# Example:
#   some.person@some.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAI109FF5EFDFF74260919CB8F54A5E7CF2
TXT

  # TODO: pre-populate with global setting, if any?
fi

git config 'gpg.ssh.allowedSignersFile' "${allowed_signers_file}"
"${editor}" "${allowed_signers_file}"
