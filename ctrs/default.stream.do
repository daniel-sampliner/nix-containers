#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

{
	printf '../fp/pkgs.nix\0'
	find "$2" -type f -print0
} | xargs -0r redo-ifchange

nix -L build ..#"$2" --out-link "$3"
