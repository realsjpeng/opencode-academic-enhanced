#!/bin/bash
# SPDX-License-Identifier: GPL-3.0-only
#
# Copyright (C) 2026 realsjpeng
# This program is free software under the GPLv3.
set -e

# Ensure log and config directories exist with proper permissions.
# This handles host-mounted volumes that may be owned by root.
mkdir -p /home/user/.local/share/opencode/log 2>/dev/null || true
chown -R user:user /home/user/.local/share/opencode /home/user/.config/opencode 2>/dev/null || true

exec su - user -s /bin/sh -c "opencode $(printf ' %q' "$@")"
