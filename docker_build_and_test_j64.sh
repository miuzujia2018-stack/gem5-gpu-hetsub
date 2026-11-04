#!/usr/bin/env bash
set -Eeuo pipefail

project_root="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
unified_root="${GEM5_UNIFIED_ROOT:-/home/siat/gem5-unified}"
unified_root="$(cd -P -- "$unified_root" && pwd)"
exec "$unified_root/scripts/compat-server-entry.sh" \
    --project-root "$project_root" "$@"
