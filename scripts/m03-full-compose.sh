#!/usr/bin/env bash
# Backwards-compatibility wrapper. Use scripts/compose-full.sh directly.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SCRIPT_DIR/compose-full.sh" "$@"
