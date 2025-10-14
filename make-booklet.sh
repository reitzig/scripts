#!/usr/bin/env bash

# Takes an A4 PDF, and rearranges pages so that an A4 duplex can be
# (cut) and stapled into a booklet of the given format.

# Requires: uvx

set -euo pipefail

original_file="${1}"
booklet_format="${2:-a5}"

basename="$(basename "${original_file}")"
basename="${basename%.*}"

tmpfile="$(mktemp)"
# shellcheck disable=SC2064
trap "rm -f '${tmpfile}'" EXIT
target_file="${basename}_${booklet_format}booklet.pdf"

case "${booklet_format}" in
    a5) signature=""    ;;
    a6) signature="1x2" ;;
    a7) signature="2x2" ;;
    *)  echo "❌ Unsupported booklet format '${booklet_format}'; use one of 'a5', 'a6', 'a7'" && exit 1 ;;
esac

# This pairs up pages so that they match up after binding
uvx pdfimpose \
    saddle \
    --signature="2x1" \
    --output="${tmpfile}" \
    "${1}"

if [[ -n "${signature}" ]]; then
    # This puts more pairs on a page for smaller booklets
    uvx pdfimpose \
        cards \
        --signature="${signature}" \
        --mark="crop" \
        --output="${target_file}" \
        "${tmpfile}"
else
    cp "${tmpfile}" "${target_file}"
fi

echo "✅ Booklet written to ${target_file}"
echo "⚠️ The resulting file does _not_ have A4 format! Take care when printing!"

