#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

case "${2##*/}" in
clean)
	redo-targets | grep -vF '^../' | xargs -r rm -f --
	;;

pushs | streams | loads)
	redo-ifchange manifest.json
	suffix="${2##*/}"
	jq -r --arg suffix "${suffix::-1}" \
		'. | keys | map("ctrs/\(.).\($suffix)") | @tsv' manifest.json \
		| xargs -r redo-ifchange
	;;

*)
	printf 'unknown target: %s\n' "${2##*/}" >&2
	exit 1
	;;
esac
