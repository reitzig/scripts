#!/usr/bin/env bash

# Copyright 2024, Raphael Reitzig
#
# shelve-photos.sh is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# shelve-photos.sh is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with shelve-photos.sh. If not, see <http://www.gnu.org/licenses/>.

# Requires: feh, gum, xdotool, yq

set -euo pipefail
#set -x

# IMAGE_VIEWER="eog"
IMAGE_VIEWER="feh -d --draw-exif --scale-down"
TARGET_FOLDER_LIST="${HOME}/.local/state/shelve-photos-targets.yaml"
CANONICAL_IMGNAME="$(dirname "$(realpath "${0}")")/canonical_imgname.rb"

BASE_TARGET_FOLDER='change it'

# TODO: Dry-run -- only log "final" action
# TODO: Option to copy instead of moving, no deletion
# TODO: How to abort?

if [ "${#}" -lt 2 ]; then
    echo "Usage: shelve-photos DIR FILE..."
fi
for tool in feh gum xdotool yq; do
    if ! which ${tool} > /dev/null 2>&1; then
        echo "FATAL ${tool} not found on PATH"
        exit 1
    fi
done


main() {
    export BASE_TARGET_FOLDER="$(realpath "${1}")"
    shift

    if [ ! -d "${BASE_TARGET_FOLDER}" ]; then
        gum log --level fatal "Target directory does not exist: ${BASE_TARGET_FOLDER}"
        exit 2
    fi

    gum log --level debug "Shelving photos into ${BASE_TARGET_FOLDER}"
    gum log --level debug "Checking for target folders in ${TARGET_FOLDER_LIST}"

    terminal_window="$(xdotool getactivewindow)"

    for file in "${@}"; do
        if [ ! -f "${file}" ]; then
            gum log --level error "No such file: ${file}"
            continue
        fi

        ${IMAGE_VIEWER} "${file}" 2>&1 > /dev/null &
        pid_viewer="${!}"
        # Wait until window has opened (and grabbed focus):
        xdotool search --sync --pid "${pid_viewer}" > /dev/null
        # xdotool windowfocus --sync "$(xdotool search --sync --pid "${pid_viewer}")"
        xdotool windowfocus --sync "${terminal_window}"

        ask_keep "${file}"

        kill "${pid_viewer}" 2>/dev/null || true
        wait "${pid_viewer}" 2>/dev/null || true
    done
}

ask_keep() {
    file="${1}"

    case "$(gum choose \
        "Yes" \
        "No" \
        "Skip" \
        --header="Keep ${file}?")" \
    in
        Yes)
        gum log --level debug "Keeping ${file}"
        ask_rename "${file}"
        ;;
        No)
        gio trash "${file}"
        gum log --level info "Trashed ${file}"
        ;;
        *)
        gum log --level debug "Skipped ${file}"
        ;;
    esac
}

ask_rename() {
    file="${1}"

    canonical_option=""
    ask_option="Yes ..."
    canonical_filename="$(basename "$("${CANONICAL_IMGNAME}" "${file}" 2> /dev/null)")"
    if [ -n "${canonical_filename}" ] \
      && [ "${canonical_filename}" != "$(basename "${file}")" ];
    then
        canonical_option="Yes: ${canonical_filename}"
        ask_option="Yes, other ..."
    fi

    choice="$(gum choose \
        "No" \
        ${canonical_option:+"${canonical_option}"} \
        "${ask_option}" \
        --header="Rename ${file}?")"
    case "${choice}" \
    in
        No)
        ask_target "${file}" "${file}"
        ;;
        Yes:*)
        ask_target "${file}" "${canonical_filename}"
        ;;
        *)
        target="$(gum input --value="${file}")"
        ask_target "${file}" "${target}"
    esac
}

_known_targets() {
    if [ -f "${TARGET_FOLDER_LIST}" ]; then
        known_targets="$(\
                yq '. | sort_by(.count, .path) | reverse' < "${TARGET_FOLDER_LIST}" \
            |   yq ".[] | select(.path | test(\"^${BASE_TARGET_FOLDER}\")) | [.]" \
            |   yq ".[] | .path | sub(\"^${BASE_TARGET_FOLDER}/\", \"\")" \
        )"
    else
        gum log --level info "No known targets, starting a new list"
        mkdir -p "$(dirname "${TARGET_FOLDER_LIST}")"
        echo '[]' > "${TARGET_FOLDER_LIST}"
    fi

    echo "${known_targets}"
}

_update_count() {
    target_dir="${1}"

    if [[ "$(yq ".[] | select(.path == \"${target_dir}\") | length // 0" < "${TARGET_FOLDER_LIST}")" -eq 0 ]]; then
        yq -i ". += {\"path\": \"${target_dir}\", \"count\": 0}" "${TARGET_FOLDER_LIST}"
    fi

    count="$(yq ".[] | select(.path == \"${target_dir}\") | .count" < "${TARGET_FOLDER_LIST}")"
    #gum log --level debug "Shelved to ${target_dir} ${count} times before"
    count=$((count+1))
    yq -i "(.[] | select(.path == \"${target_dir}\") | .count) = ${count}" "${TARGET_FOLDER_LIST}"
}

ask_target() {
    file="${1}"
    target="${2}"

    gum log --level debug "Relocating ${file} as ${target}"

    target_dir=""
    choice="$(gum choose \
        $(_known_targets) \
        "Other ..." \
        --header="Choose target folder")"
    case "${choice}"
    in
        Other*)
        target_dir="$(gum file --directory "${BASE_TARGET_FOLDER}")"
        ;;
        *)
        target_dir="${BASE_TARGET_FOLDER}/${choice}"
        ;;
    esac

    _update_count "${target_dir}"
    move "${file}" "${target_dir}/${target}"
}

move() {
    file="${1}"
    target="${2}"

    # TODO: check if we overwrite!
    mv "${file}" "${target}"
    gum log --level info "Shelved ${file} as ${target}"
}

main "${@}"
