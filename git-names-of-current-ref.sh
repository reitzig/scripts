#!/usr/bin/env bash

git for-each-ref \
    --format='%(refname:short)' \
    --sort="refname:short" \
    --contains HEAD \
    --merged HEAD \
    refs/heads/ \
    refs/tags/
