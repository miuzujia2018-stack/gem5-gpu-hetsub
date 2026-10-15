#!/bin/bash
set -Eeuo pipefail

export CUDAHOME=/usr/local/cuda/cuda
export PATH=/usr/local/cuda/cuda/bin:/usr/local/cuda/bin:/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

project_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
provenance_guard="${project_dir}/tools/reproduction/verify_gem5_build.sh"
test=${1:-backprop}
(( $# == 0 )) || shift
extra_args=("$@")
out_root="${GEM5GPU_APP_OUT_ROOT:-${project_dir}/m5out/hetsub_apps/$(date -u '+%Y%m%dT%H%M%SZ')}"
[[ "$out_root" = /* ]] || { echo 'Application output root must be absolute' >&2; exit 2; }
[[ -x "$provenance_guard" ]] || { echo "ERROR: missing build provenance guard: $provenance_guard" >&2; exit 42; }

run_test() {
    local name=$1 bin=$2 opts=$3
    local outdir="${out_root}/${name}"
    [[ ! -e "$outdir" ]] || { echo "Refusing to overwrite $outdir" >&2; exit 2; }
    mkdir -p "$outdir"
    "$provenance_guard" verify "$project_dir" X86_VI_hammer_GPU
    echo "=== Testing: $name ($outdir) ==="
    (
      cd "$outdir"
      "$project_dir/gem5/build/X86_VI_hammer_GPU/gem5.opt" \
        -d "$outdir" "$project_dir/gem5-gpu/configs/se_fusion.py" \
        --garnet-network=flexible --topology=Mesh8x8_CPU_GPU --mesh-rows=8 \
        --cpu-type=timing --num-cpus=16 --num-dirs=4 --num-l2caches=40 \
        --mem-channels=8 --clusters=16 --cores_per_cluster=1 \
        --sys-clock=1GHz --cpu-clock=2GHz --ruby-clock=2GHz --cacheline_size=128 \
        --random_seed=1234 --topology-seed=0 \
        --network-vcs-per-vnet=2 --network-buffer-size=4 --network-pipeline-stages=2 \
        -c "$bin" -o "$opts" ${extra_args[@]+"${extra_args[@]}"} \
        > "$outdir/stdout.log" 2> "$outdir/stderr.log"
    )
    echo "  $name: done (stats: $(wc -c < "$outdir/stats.txt") bytes)"
}

case "$test" in
    backprop|both)
        run_test backprop "$project_dir/benchmarks/rodinia/backprop/gem5_fusion_backprop" "16"
        ;;
    kmeans) ;;
    *) echo "Usage: $0 {backprop|kmeans|both} [simulator configuration options]" >&2; exit 2 ;;
esac
if [[ "$test" == kmeans || "$test" == both ]]; then
    run_test kmeans "$project_dir/benchmarks/rodinia/kmeans/gem5_fusion_kmeans" \
        "-i $project_dir/kmeans_input.txt -o -r"
fi
