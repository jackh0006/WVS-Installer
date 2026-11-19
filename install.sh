#!/usr/bin/env bash
# SPDX-License-Identifier: MIT
# Copyright (c) 2026 jackh0006
#
# Quick entry point: run the installer that lives next to this file.
set -Eeuo pipefail

HERE=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
exec bash "$HERE/vps-setup.sh" "$@"
