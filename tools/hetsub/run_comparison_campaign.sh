#!/usr/bin/env bash
set -Eeuo pipefail

root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." && pwd)"
tag="${1:-formal_10c_v1}"
[[ "$tag" =~ ^[A-Za-z0-9_.-]+$ ]] || { echo 'invalid tag' >&2; exit 2; }
out="$root/m5out/comparison_10c/$tag"
reference="$root/m5out/hetsub_apps/reference/backprop_cpu.txt"
[[ -s "$reference" ]] || { echo "missing CPU backprop reference: $reference" >&2; exit 2; }

run_case() {
    local repo=$1 method=$2 app=$3
    shift 3
    python3 "$root/tools/hetsub/run_comparison.py" "$repo" "$app" \
        --method "$method" --tag "$tag" "$@"
    local run="$out/${repo}_${method}/${app}"
    if [[ "$app" == backprop ]]; then
        python3 "$root/tools/hetsub/validate_apps.py" "$run" \
            --backprop-reference "$reference"
    else
        python3 "$root/tools/hetsub/validate_apps.py" "$run" \
            --kmeans-input "$root/kmeans_input.txt"
    fi
}

mkdir -p "$out/configs"
for app in backprop kmeans; do
    run_case hetsub pilot "$app"
    python3 "$root/tools/hetsub/insert_shortcuts.py" \
        --profile "$out/hetsub_pilot/$app/profile.csv" \
        --output "$out/configs/$app.json" --threshold-bytes=128 --limit=4
done

for app in backprop kmeans; do
    run_case hetsub xy "$app"
    run_case hetsub dual8 "$app"
    run_case hetsub dual7 "$app"
    run_case hetsub static8 "$app" --shortcuts "$out/configs/$app.json"
    run_case hetsub static7 "$app" --shortcuts "$out/configs/$app.json"
    run_case tbp tbp "$app"
    run_case bak xy "$app"
    run_case bak bak "$app"

    runs=()
    for name in hetsub_xy hetsub_dual8 hetsub_dual7 hetsub_static8 \
                hetsub_static7 tbp_tbp bak_xy bak_bak; do
        runs+=("$out/$name/$app")
    done
    python3 "$root/tools/hetsub/audit_comparison.py" \
        --reference "$out/hetsub_xy/$app" "${runs[@]}" \
        > "$out/audit_${app}.json"
done

echo "Formal comparison completed: $out"
