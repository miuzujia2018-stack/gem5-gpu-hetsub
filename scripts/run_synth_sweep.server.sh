#!/usr/bin/env bash
# In-container implementation of the 3-pattern synthetic traffic sweep for the
# unified server.  The legacy Docker wrapper (docker cp into the xy container)
# is preserved under gem5-unified/manifests/legacy-specialized-20261028/.
# Simulation only: parse/plot still run on the host that invoked the shim.
set -Eeuo pipefail
case "${GEM5_ENV_PROFILE:-}" in
    hetsub|hetsub-upper) ;;
    *)
        echo 'server implementation must run through gem5-unified/server-command.sh' >&2
        exit 2
        ;;
esac
ROOT="${GEM5_ENV_PROJECT_ROOT:?GEM5_ENV_PROJECT_ROOT missing}"
cd "$ROOT"
export LC_ALL=C.UTF-8 LANG=C.UTF-8
# Provenance gate: the sweep must run this profile's credential-verified
# X86_Network_test binary, never an older binary.
tools/reproduction/verify_gem5_build.sh verify "$ROOT" X86_Network_test
rm -rf "${ROOT}/m5out/synth"
mkdir -p "${ROOT}/m5out/synth"
bash scripts/sweep_synth_traffic.sh --sim-cycles 100000 --random_seed 42 --skip-post
