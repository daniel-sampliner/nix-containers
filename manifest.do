#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

{
	printf '%s\n' flake.lock flake.nix fp/pkgs.nix
	find ctrs -name '*.nix'
} | xargs -r redo-ifchange

nix -L build .#manifest -o "$3"
