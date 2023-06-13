#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

redo-always
redo-ifchange "$2.stream" ../manifest.json

read -r name tag < <(
	# shellcheck disable=SC2016
	jq -r --arg pkg "$2" \
		'.[$pkg] | [.name, .tag ] |@tsv' \
		../manifest.json
)

img=$(mktemp "$3.XXXXXX")
trap 'rm -f -- "$img"' EXIT

./"$2.stream" | pigz -nTR >"${img:?}"

for t in "${tag:?}" latest; do
	skopeo copy \
		"docker-archive:$img" \
		"docker://${REGISTRY:?}/${ORG:?}/$name:$t" >&2
done
