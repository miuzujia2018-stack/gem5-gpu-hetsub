#!/usr/bin/env bash
set -Eeuo pipefail

ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
BASE_CONTAINER="${GEM5GPU_BASE_CONTAINER:-gem5gpu-dev-hetsub}"
JOBS="${GEM5GPU_JOBS:-64}"
GUARD="${ROOT}/tools/reproduction/verify_gem5_build.sh"

[[ -x "$GUARD" ]] || { printf 'ERROR: missing provenance guard: %s\n' "$GUARD" >&2; exit 42; }
sudo docker inspect "$BASE_CONTAINER" >/dev/null 2>&1 || {
    printf 'ERROR: Docker base container not found: %s\n' "$BASE_CONTAINER" >&2
    exit 1
}
if [[ "$(sudo docker inspect -f '{{.State.Running}}' "$BASE_CONTAINER")" != true ]]; then
    sudo docker start "$BASE_CONTAINER" >/dev/null
fi

image="$(sudo docker inspect -f '{{.Config.Image}}' "$BASE_CONTAINER")"
source_before="$("$GUARD" fingerprint "$ROOT")"
printf 'Verified Network_test build tree: %s\n' "$ROOT"
printf 'Source fingerprint before build: %s\n' "$source_before"

# The explicit bind always wins over any same-named directory inherited from
# the base container, preventing an accidental build of a sibling tree.
sudo docker run --rm \
    --volumes-from "$BASE_CONTAINER" \
    --volume "${ROOT}:${ROOT}" \
    --workdir "${ROOT}/gem5" \
    "$image" \
    /bin/bash --noprofile --norc -c "
        set -e
        mkdir -p /tmp
        export CUDAHOME=/usr/local/cuda/cuda
        export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
        export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
        # A clean target makes it impossible to certify an old executable.
        rm -rf -- build/X86_Network_test
        scons build/X86_Network_test/gem5.opt \\
            --default=X86 \\
            EXTRAS=../gem5-gpu/src:../gpgpu-sim/ \\
            PROTOCOL=Network_test \\
            -j${JOBS}
    "

EXPECTED_SOURCE_SHA256="$source_before" \
    "$GUARD" record "$ROOT" X86_Network_test
"$GUARD" verify "$ROOT" X86_Network_test
printf 'Verified Network_test build complete.\n'
