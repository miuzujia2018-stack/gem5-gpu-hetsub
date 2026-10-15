#!/usr/bin/env bash
set -Eeuo pipefail

# Bind a gem5 binary to the exact source-tree contents that produced it.
# A test launcher must call "verify" before executing gem5.opt.  A build
# wrapper calls "record" only after SCons has completed successfully.

die() {
    printf 'BUILD-PROVENANCE ERROR: %s\n' "$*" >&2
    exit 42
}

usage() {
    printf 'Usage: %s {record|verify|show|fingerprint} PROJECT_ROOT [BUILD_NAME]\n' "$0" >&2
    exit 2
}

[[ $# -ge 2 ]] || usage
mode="$1"
project_root="$(cd -P -- "$2" && pwd)"
build_name="${3:-X86_VI_hammer_GPU}"

[[ "$build_name" =~ ^[A-Za-z0-9_.-]+$ ]] || die "invalid build name: $build_name"

binary="${project_root}/gem5/build/${build_name}/gem5.opt"
stamp_dir="${project_root}/.build_provenance"
stamp="${stamp_dir}/${build_name}.env"

sha_file() {
    local output
    [[ -r "$1" ]] || die "cannot read file while fingerprinting: $1"
    output="$(sha256sum -- "$1")" || die "sha256sum failed for: $1"
    printf '%s\n' "${output%% *}"
}

source_fingerprint() {
    local repo rel file digest head
    {
        for repo in gem5 gem5-gpu gpgpu-sim; do
            [[ -d "${project_root}/${repo}" ]] || die "missing source tree: ${project_root}/${repo}"
            git -C "${project_root}/${repo}" rev-parse --is-inside-work-tree >/dev/null 2>&1 ||
                die "not a Git work tree: ${project_root}/${repo}"

            # HEAD covers unchanged tracked files; the binary diff covers both
            # staged and unstaged changes.  Hash non-ignored untracked files as
            # well, because SCons may discover newly added source files.
            head="$(git -C "${project_root}/${repo}" rev-parse HEAD)"
            printf 'repo=%s\0head=%s\0' "$repo" "$head"
            # Old Docker Git defaults to 7-character index IDs; current Git
            # chooses a repository-dependent abbreviation. Hash the same
            # patch on both sides of the bind mount, using full object IDs.
            git -C "${project_root}/${repo}" -c diff.indentHeuristic=false \
                diff --binary --full-index --no-ext-diff HEAD -- . \
                ':(exclude)**/*.pyc' ':(exclude)**/*.pyo'
            while IFS= read -r -d '' rel; do
                case "$rel" in
                    *.pyc|*.pyo|*/__pycache__/*) continue ;;
                esac
                file="${project_root}/${repo}/${rel}"
                [[ -f "$file" ]] || continue
                digest="$(sha_file "$file")"
                printf '%s\0%s\0' "${repo}/${rel}" "$digest"
            done < <(git -C "${project_root}/${repo}" ls-files -o --exclude-standard -z | LC_ALL=C sort -z)
        done
    } | sha256sum | awk '{print $1}'
}

read_stamp_value() {
    local key="$1"
    awk -F= -v wanted="$key" '$1 == wanted { sub(/^[^=]*=/, ""); print; exit }' "$stamp"
}

record_stamp() {
    local source_sha binary_sha binary_size tmp
    [[ -x "$binary" ]] || die "missing executable binary: $binary"
    source_sha="$(source_fingerprint)"
    if [[ -n "${EXPECTED_SOURCE_SHA256:-}" && "$source_sha" != "$EXPECTED_SOURCE_SHA256" ]]; then
        die "source tree changed while SCons was running (${EXPECTED_SOURCE_SHA256} != ${source_sha}); build again"
    fi
    binary_sha="$(sha_file "$binary")"
    binary_size="$(stat -c '%s' "$binary")"

    mkdir -p -- "$stamp_dir"
    chmod a+rwx -- "$stamp_dir"
    tmp="$(mktemp "${stamp}.tmp.XXXXXX")"
    {
        printf 'format=1\n'
        printf 'build_name=%s\n' "$build_name"
        printf 'source_sha256=%s\n' "$source_sha"
        printf 'binary_sha256=%s\n' "$binary_sha"
        printf 'binary_size=%s\n' "$binary_size"
        printf 'recorded_utc=%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
    } >"$tmp"
    chmod a+r -- "$tmp"
    mv -f -- "$tmp" "$stamp"
    printf 'BUILD-PROVENANCE RECORDED: %s source=%s binary=%s\n' \
        "$build_name" "$source_sha" "$binary_sha"
}

verify_stamp() {
    local expected_source expected_binary actual_source actual_binary expected_size actual_size
    [[ -r "$stamp" ]] || die "no build credential for ${build_name}; run the Docker build-and-test script"
    [[ -x "$binary" ]] || die "missing executable binary: $binary"

    expected_source="$(read_stamp_value source_sha256)"
    expected_binary="$(read_stamp_value binary_sha256)"
    expected_size="$(read_stamp_value binary_size)"
    [[ "$expected_source" =~ ^[0-9a-f]{64}$ ]] || die "invalid source fingerprint in $stamp"
    [[ "$expected_binary" =~ ^[0-9a-f]{64}$ ]] || die "invalid binary fingerprint in $stamp"

    actual_source="$(source_fingerprint)"
    actual_binary="$(sha_file "$binary")"
    actual_size="$(stat -c '%s' "$binary")"

    [[ "$actual_source" == "$expected_source" ]] ||
        die "source tree changed after the last successful build (${expected_source} != ${actual_source}); rebuild before testing"
    [[ "$actual_binary" == "$expected_binary" ]] ||
        die "gem5.opt changed after the recorded build (${expected_binary} != ${actual_binary}); rebuild before testing"
    [[ "$actual_size" == "$expected_size" ]] ||
        die "gem5.opt size differs from the recorded build; rebuild before testing"

    printf 'BUILD-PROVENANCE VERIFIED: %s source=%s binary=%s\n' \
        "$build_name" "$actual_source" "$actual_binary"
}

case "$mode" in
    record) record_stamp ;;
    verify) verify_stamp ;;
    show) [[ -r "$stamp" ]] || die "missing credential: $stamp"; cat -- "$stamp" ;;
    fingerprint) source_fingerprint ;;
    *) usage ;;
esac
