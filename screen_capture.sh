#!/usr/bin/env bash

set -euo pipefail

tmp_file="$(mktemp --suffix '_menyoki.gif')"

gum log --level=info "Select area to start recording"
area="$(slop)"

gum log --level=info "Recording ${area}; press ^C to stop and save"
menyoki record --root --size "${area}" gif --fast save "${tmp_file}"

target_file="${HOME}/Screenshots/$(date '+%Y-%m-%d %H.%M.%S') Capture.mp4"
ffmpeg -v warning -i "${tmp_file}" "${target_file}" \
  && rm -f "${tmp_file}"
gum log --level=info "Recording saved as '${target_file}'"
