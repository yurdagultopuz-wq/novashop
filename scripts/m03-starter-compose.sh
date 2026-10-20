#!/usr/bin/env bash
# Backwards-compatibility wrapper. Use scripts/compose-starter.sh directly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/compose-starter.sh" "$@"
