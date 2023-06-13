#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

redo-always
redo-ifchange "$2.stream" ../manifest

while read -r pkg name tag; do
	[[ $pkg == "$2" ]] && break
done <../manifest
if [[ -z $pkg ]]; then
	printf 'could not find package in manifest: %s\n' "$2" >&2
	exit 1
fi

img=$(mktemp "$3.XXXXXX")
trap 'rm -f -- "$img"' EXIT

./"$2.stream" | pigz -nTR >"$img"

for t in "$tag" latest; do
	skopeo copy \
		"docker-archive:$img" \
		"docker://${REGISTRY:?}/${ORG:?}/$name:$t" >&2
done
