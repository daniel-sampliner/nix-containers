#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

redo-always
redo-ifchange "$2.stream" ../manifest.json

./"$2.stream" | podman image load >&2

read -r name tag < <(
	# shellcheck disable=SC2016
	jq -r --arg pkg "$2" \
		'.[$pkg] | [.name, .tag ] |@tsv' \
		../manifest.json
)
podman image tag "${name:?}:${tag:?}" "$name:latest"
