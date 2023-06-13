#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

case "${2##*/}" in
	clean)
		redo-targets | grep -vF '^../' | xargs -r rm -f --
		;;
	*)
		printf 'unknown target: %s\n' "${2##*/}" >&2
		exit 1
		;;
esac
