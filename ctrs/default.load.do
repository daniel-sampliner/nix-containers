#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

redo-always
redo-ifchange "$2.stream" ../manifest

./"$2.stream" | podman image load >&2
while read -r pkg name version; do
	[[ $pkg != "$2" ]] && continue
	podman image tag "$name:$version" "$name:latest"
	break
done <../manifest
