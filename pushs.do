#!/usr/bin/env bash

# SPDX-FileCopyrightText: 2023 Daniel Sampliner <samplinerD@gmail.com>
#
# SPDX-License-Identifier: GLWTPL

set -e

redo-ifchange manifest

cut -d$'\t' -f1 manifest \
	| sed 's:^:ctrs/:; s:$:.push:' \
	| xargs -r redo-ifchange
