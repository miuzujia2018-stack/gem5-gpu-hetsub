#!/usr/bin/env bash
set -Eeuo pipefail

# Compatibility name retained for scripts and notebooks that still invoke
# docker_build_and_test_*.sh.  The implementation is now always the remote
# rootless-Podman workflow; no Docker daemon or local build is used.

project="${GEM5_UNIFIED_PROFILE:-}"
if [[ -z "$project" ]]; then
    case "$(basename -- "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)")" in
        gem5-gpu-ai) project=ai ;;
        gem5-gpu-ai-ftca-ql) project=ftca-ql ;;
        gem5-gpu-ai-ftca-ql-clean-baseline) project=ftca-ql-clean-baseline ;;
        gem5-gpu-ai-ftca-ql-hw-r1a) project=ftca-ql-hw-r1a ;;
        gem5-gpu-ai-ftiet) project=ftiet ;;
        gem5-gpu-bak) project=bak ;;
        gem5-gpu-chiplets) project=chiplets ;;
        gem5-gpu-chiplets-rebl) project=rebl ;;
        gem5-gpu-chiplets-red) project=chiplets-red ;;
        gem5-gpu-hetsub) project=hetsub ;;
        gem5-gpu-HetSub) project=hetsub-upper ;;
        gem5-gpu-mvpp) project=mvpp ;;
        gem5-gpu-tbp) project=tbp ;;
        gem5-gpu-xy) project=xy ;;
        ftca_ql_review_cee60173) project=ftca-ql-review ;;
        ftca_ql_step4) project=ftca-ql-step4 ;;
        *)
            printf 'No unified server profile is registered for %s\n' \
                "$(basename -- "$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)")" >&2
            exit 2
            ;;
    esac
fi

exec /home/siat/gem5-unified/scripts/server-build-and-test.sh \
    "$project" "${1:-build}" "${2:-all}"
