#!/usr/bin/env bash
set -Eeuo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
CONTAINER="${GEM5GPU_BASE_CONTAINER:-gem5gpu-dev-hetsub}"
TAG="${HETSUB_TEST_TAG:-$(date -u '+%Y%m%dT%H%M%SZ')}"
[[ "$TAG" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'Invalid test output tag' >&2; exit 2; }
OUT="${ROOT}/m5out/hetsub_network/${TAG}"
[[ ! -e "$OUT" ]] || { echo "Refusing to overwrite $OUT" >&2; exit 2; }
mkdir -p "$OUT"
echo "HetSub functional outputs: $OUT"
failed=0

# Use the target 2GHz clock with 1ps ticks. A 1GHz line control checks that
# sim-cycles describes cycles independently of the tick resolution.
# Each run checks the mandatory credential.
for case_name in ${HETSUB_TEST_CASES:-off line mesh8 mesh7 policy policy_load independence pg_line pg_mesh line_1ghz static8 static7 static_two static_abstract line_bit_reverse mesh_bit_reverse static_transpose pilot static_pilot reject_conflict reject_nonadjacent static_level2}; do
    pg_args=(); shortcut_args=()
    mode=dual; packets=4; rate=0.01; frequency=2GHz; reject=0; pattern=0; seed=42; profile=0
    case "$case_name" in
        off) mode=off; forced=-1; width=8 ;;
        line) forced=0; width=8 ;;
        line_1ghz) forced=0; width=8; frequency=1GHz ;;
        mesh8) forced=1; width=8 ;;
        mesh7) forced=1; width=7 ;;
        policy) forced=-1; width=8 ;;
        policy_load) forced=-1; width=8; packets=16; rate=0.05 ;;
        independence) forced=-1; width=8; packets=64; rate=0.1; pg_args=(--hetsub-pg) ;;
        pg_line) forced=0; width=8; pg_args=(--hetsub-pg) ;;
        pg_mesh) forced=1; width=8; pg_args=(--hetsub-pg) ;;
        line_bit_reverse) forced=0; width=8; packets=16; rate=0.05; pattern=1 ;;
        mesh_bit_reverse) forced=1; width=7; packets=16; rate=0.05; pattern=1 ;;
        pilot) forced=0; width=8; packets=16; rate=0.05; seed=17; profile=1 ;;
        static_pilot)
            mode=static; forced=-1; width=7; packets=16; rate=0.05
            shortcut_args=(--hetsub-shortcuts="$OUT/pilot/shortcuts.json")
            [[ -f "$OUT/pilot/shortcuts.json" ]] || { echo 'Run pilot before static_pilot' >&2; exit 2; }
            ;;
        static8|static7|static_two|static_abstract|static_transpose)
            mode=static; forced=-1; width=8
            fixture=static_one
            [[ "$case_name" != static7 ]] || width=7
            [[ "$case_name" != static_two ]] || fixture=static_two
            if [[ "$case_name" == static_transpose ]]; then
                fixture=static_two; width=7; packets=16; rate=0.05; pattern=2
            fi
            shortcut_args=(--hetsub-shortcuts="$ROOT/tools/hetsub/fixtures/$fixture.json")
            [[ "$case_name" != static_abstract ]] || shortcut_args+=(--hetsub-bypass-abstract)
            ;;
        reject_conflict|reject_nonadjacent)
            mode=static; forced=-1; width=8; reject=1
            fixture="static_${case_name#reject_}"
            shortcut_args=(--hetsub-shortcuts="$ROOT/tools/hetsub/fixtures/$fixture.json")
            ;;
        static_level2)
            mode=static; forced=-1; width=7; packets=16; rate=0.05; pattern=2
            shortcut_args=(--hetsub-shortcuts="$ROOT/tools/hetsub/fixtures/static_level2.json")
            ;;
        *) echo "Unknown test case: $case_name" >&2; exit 2 ;;
    esac
    run_dir="${OUT}/${case_name}"
    mkdir -p "$run_dir"
    (( ! profile )) || shortcut_args+=(--hetsub-profile="$run_dir/profile.csv")
    if ! sudo docker exec --workdir "$ROOT" "$CONTAINER" \
        /bin/bash -c 'set -e; tools/reproduction/verify_gem5_build.sh verify "$PWD" X86_Network_test; exec gem5/build/X86_Network_test/gem5.opt "$@"' \
        het-test -d "$run_dir" gem5/configs/example/ruby_network_test.py \
        --garnet-network=flexible --topology=Mesh --mesh-rows=8 \
        --num-cpus=64 --num-dirs=64 --sys-clock="$frequency" --ruby-clock="$frequency" \
        --network-vcs-per-vnet=2 --network-buffer-size=4 --network-pipeline-stages=2 \
        --fixed-pkts --maxpackets="$packets" --sim-cycles=12000 \
        --injectionrate="$rate" --synthetic="$pattern" --random_seed="$seed" \
        --hetsub-mode="$mode" --hetsub-force-subnet="$forced" \
        --hetsub-mesh-bytes="$width" "${pg_args[@]}" "${shortcut_args[@]}" \
        > "$run_dir/stdout.log" 2> "$run_dir/stderr.log"; then
        if (( reject )) && rg -q 'fatal:.*(crossbar/local-port/physical-edge conflict|nonadjacent mesh tiles)' "$run_dir"/*.log; then
            echo "PASS $case_name: invalid physical configuration rejected"
            continue
        fi
        echo "FAIL $case_name: simulator exited unsuccessfully" >&2
        failed=1
        continue
    fi
    if (( reject )); then
        echo "FAIL $case_name: invalid configuration was accepted" >&2
        failed=1
        continue
    fi
    if ! python3 "$ROOT/tools/hetsub/validate_network.py" "$run_dir" "$case_name"; then
        failed=1
        continue
    fi
    if [[ "$mode" != off ]]; then
        python3 "$ROOT/tools/hetsub/check_dependencies.py" "$run_dir/config.ini" \
            > "$run_dir/channel_dependencies.json" || failed=1
    fi
    if (( profile )); then
        python3 "$ROOT/tools/hetsub/insert_shortcuts.py" \
            --profile "$run_dir/profile.csv" --output "$run_dir/shortcuts.json" \
            --threshold-bytes=128 --limit=4 > "$run_dir/insertion.log" 2>&1 || failed=1
    fi
done
exit "$failed"
