#!/usr/bin/env bash
set -Eeuo pipefail

# SSH-only backup workflow for the six gem5 project repositories.
# The nested repositories are pushed first; the parent gitlinks are then
# updated and the parent repository is pushed last.

PROJECT_ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_NAME="$(basename "$PROJECT_ROOT")"
SSH_KEY="${GEM5_SSH_KEY:-${HOME}/.ssh/id_ed25519_miuzujia2018_stack}"
GITHUB_HOST="${GEM5_GITHUB_HOST:-github-miuzujia}"
GIT_SSH_COMMAND="ssh -o BatchMode=yes -o IdentitiesOnly=yes -i ${SSH_KEY}"

export GIT_SSH_COMMAND

MAIN_REPO_URL=""
declare -a MAIN_PUSH_REFS=()
declare -a SUBMODULES=()

add_submodule() {
    local path="$1" url="$2" branch="$3" name="$4" pushable="${5:-1}"
    SUBMODULES+=("${PROJECT_ROOT}/${path}|${url}|${branch}|${name}|${pushable}")
}

case "$PROJECT_NAME" in
    gem5-gpu-bak)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-bak.git"
        MAIN_PUSH_REFS=("master")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-bak gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" master gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" master gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" master Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" master benchmarks
        add_submodule manuscript "git@${GITHUB_HOST}:miuzujia2018-stack/transaction_on_sustainable_computing.git" master manuscript
        add_submodule mvpp_manuscript "git@${GITHUB_HOST}:miuzujia2018-stack/mvpp_manuscript.git" master mvpp_manuscript
        add_submodule Research-Paper-Writing-Skills "git@github.com:Master-cai/Research-Paper-Writing-Skills.git" main Research-Paper-Writing-Skills 0
        ;;
    gem5-gpu-hetsub)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-hetsub.git"
        MAIN_PUSH_REFS=("synthetic-traffic-three-patterns")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-hetsub gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" gem5-gpu-xy gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" gem5-gpu-xy gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" gem5-gpu-xy Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" gem5-gpu-hetsub benchmarks
        ;;
    gem5-gpu-HetSub)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-hetsub.git"
        MAIN_PUSH_REFS=("HEAD:gem5-gpu-HetSub")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-HetSub gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" gem5-gpu-xy gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" gem5-gpu-xy gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" gem5-gpu-xy Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" gem5-gpu-hetsub benchmarks
        ;;
    gem5-gpu-tbp)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-tbp.git"
        MAIN_PUSH_REFS=("master")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-tbp gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" gem5-gpu-tbp gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" gem5-gpu-tbp gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" gem5-gpu-tbp Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" gem5-gpu-tbp benchmarks
        ;;
    gem5-gpu-xy)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-xy.git"
        MAIN_PUSH_REFS=("gem5-gpu-xy")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-xy gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" gem5-gpu-xy gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" gem5-gpu-xy gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" gem5-gpu-xy Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" gem5-gpu-xy benchmarks
        ;;
    gem5-gpu-mvpp)
        MAIN_REPO_URL="git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu-mvpp.git"
        MAIN_PUSH_REFS=("hpca" "HEAD:gem5-gpu-mvpp")
        add_submodule gem5 "git@${GITHUB_HOST}:miuzujia2018-stack/gem5.git" gem5-gpu-mvpp gem5
        add_submodule gem5-gpu "git@${GITHUB_HOST}:miuzujia2018-stack/gem5-gpu.git" gem5-gpu-mvpp gem5-gpu
        add_submodule gpgpu-sim "git@${GITHUB_HOST}:miuzujia2018-stack/gpgpu-sim.git" gem5-gpu-mvpp gpgpu-sim
        add_submodule Graphite "git@${GITHUB_HOST}:miuzujia2018-stack/graphite.git" gem5-gpu-mvpp Graphite
        add_submodule benchmarks "git@${GITHUB_HOST}:miuzujia2018-stack/benchmarks.git" gem5-gpu-mvpp benchmarks
        add_submodule manuscript "git@${GITHUB_HOST}:miuzujia2018-stack/transaction_on_sustainable_computing.git" hpca manuscript
        add_submodule mvpp_manuscript "git@${GITHUB_HOST}:miuzujia2018-stack/mvpp_manuscript.git" master mvpp_manuscript
        add_submodule Research-Paper-Writing-Skills "git@github.com:Master-cai/Research-Paper-Writing-Skills.git" main Research-Paper-Writing-Skills 0
        ;;
    *)
        printf 'Unsupported project directory: %s\n' "$PROJECT_NAME" >&2
        exit 2
        ;;
esac

MODE="push"
SUBMODULES_ENABLED=1
LOG_DIR="${PROJECT_ROOT}/build_logs"
mkdir -p "$LOG_DIR"
LOG_FILE="${LOG_DIR}/push_all_$(date +%Y%m%d_%H%M%S).log"

say() {
    printf '[%s] %s\n' "$PROJECT_NAME" "$*"
}

die() {
    printf '[%s] ERROR: %s\n' "$PROJECT_NAME" "$*" >&2
    exit 1
}

git_repo() {
    local repo="$1"
    shift
    git -C "$repo" -c "core.sshCommand=${GIT_SSH_COMMAND}" "$@"
}

repo_head() {
    git_repo "$1" rev-parse --verify HEAD
}

repo_branch() {
    git_repo "$1" symbolic-ref --quiet --short HEAD 2>/dev/null || printf 'DETACHED\n'
}

repo_dirty() {
    [[ -n "$(git_repo "$1" status --porcelain --untracked-files=all)" ]]
}

remote_head() {
    git_repo "$1" ls-remote origin "refs/heads/$2" 2>/dev/null | awk 'NR == 1 { print $1 }'
}

ensure_ssh_key() {
    [[ -r "$SSH_KEY" ]] || die "SSH key is not readable: $SSH_KEY"
}

ensure_remote() {
    local repo="$1" expected="$2" current pushurl
    current="$(git_repo "$repo" remote get-url origin 2>/dev/null || true)"
    if [[ -z "$current" ]]; then
        [[ "$MODE" == check ]] && die "$repo has no origin remote"
        git_repo "$repo" remote add origin "$expected"
    elif [[ "$current" != "$expected" ]]; then
        [[ "$MODE" == check ]] && die "$repo origin is $current, expected $expected"
        git_repo "$repo" remote set-url origin "$expected"
    fi

    pushurl="$(git_repo "$repo" config --get remote.origin.pushurl 2>/dev/null || true)"
    if [[ -n "$pushurl" && "$pushurl" != "$expected" ]]; then
        [[ "$MODE" == check ]] && die "$repo has a non-SSH pushurl: $pushurl"
        git_repo "$repo" config --unset-all remote.origin.pushurl || true
    fi

    if [[ "$MODE" == push ]]; then
        git_repo "$repo" config core.sshCommand "$GIT_SSH_COMMAND"
    fi
}

ensure_branch() {
    local repo="$1" expected="$2" current remote_ref
    current="$(repo_branch "$repo")"
    [[ "$current" == "$expected" ]] && return 0
    [[ "$MODE" == check ]] && die "$repo is on branch $current, expected $expected"
    repo_dirty "$repo" && die "$repo is dirty; refusing to switch from $current to $expected"

    if git_repo "$repo" show-ref --verify --quiet "refs/heads/$expected"; then
        git_repo "$repo" switch "$expected"
        return 0
    fi

    remote_ref="$(remote_head "$repo" "$expected" || true)"
    if [[ -n "$remote_ref" ]]; then
        git_repo "$repo" fetch origin "$expected"
        git_repo "$repo" switch --track -c "$expected" "origin/$expected"
    else
        git_repo "$repo" switch -c "$expected"
    fi
}

commit_changes() {
    local repo="$1" label="$2"
    if [[ "$MODE" == check ]]; then
        repo_dirty "$repo" && die "$label still has uncommitted or untracked files"
        return 0
    fi

    git_repo "$repo" add -A
    if git_repo "$repo" diff --cached --quiet; then
        return 0
    fi
    git_repo "$repo" commit -m "Backup ${PROJECT_NAME}/${label} $(date '+%Y-%m-%d %H:%M:%S')"
}

push_and_verify() {
    local repo="$1" source_ref="$2" target_branch="$3" label="$4"
    local expected actual
    expected="$(git_repo "$repo" rev-parse --verify "${source_ref}^{commit}")"
    if [[ "$MODE" == push ]]; then
        say "Pushing $label: $source_ref -> $target_branch"
        git_repo "$repo" push origin "${source_ref}:${target_branch}"
    fi
    actual="$(remote_head "$repo" "$target_branch" || true)"
    [[ "$actual" == "$expected" ]] || die "$label remote $target_branch is ${actual:-<missing>}, expected $expected"
}

process_submodule() {
    local entry="$1" path url branch label pushable
    IFS='|' read -r path url branch label pushable <<< "$entry"
    [[ -d "$path" ]] || die "Missing repository directory: $path"
    git_repo "$path" rev-parse --is-inside-work-tree >/dev/null || die "Not a Git worktree: $path"

    if [[ "$pushable" != 1 ]]; then
        say "Checking read-only external submodule $label"
        repo_dirty "$path" && say "WARNING: $label has local changes and is intentionally not pushed"
        return 0
    fi

    say "Processing $label (branch: $branch)"
    ensure_remote "$path" "$url"
    ensure_branch "$path" "$branch"
    commit_changes "$path" "$label"
    push_and_verify "$path" "$branch" "$branch" "$label"
}

verify_parent_links() {
    local entry path url branch label pushable rel expected actual
    for entry in "${SUBMODULES[@]}"; do
        IFS='|' read -r path url branch label pushable <<< "$entry"
        rel="${path#${PROJECT_ROOT}/}"
        expected="$(repo_head "$path")"
        actual="$(git_repo "$PROJECT_ROOT" ls-files --stage -- "$rel" | awk '$1 == "160000" { print $2; exit }')"
        [[ -n "$actual" ]] || die "Parent is missing gitlink: $rel"
        if [[ "$actual" != "$expected" ]]; then
            if [[ "$MODE" == push && "$SUBMODULES_ENABLED" == 1 ]]; then
                git_repo "$PROJECT_ROOT" add -- "$rel"
            else
                die "Parent gitlink $rel is $actual, but local submodule is $expected"
            fi
        fi
    done
}

process_main() {
    local ref source target
    say "Processing parent repository"
    ensure_remote "$PROJECT_ROOT" "$MAIN_REPO_URL"
    verify_parent_links
    commit_changes "$PROJECT_ROOT" parent

    for ref in "${MAIN_PUSH_REFS[@]}"; do
        if [[ "$ref" == *:* ]]; then
            source="${ref%%:*}"
            target="${ref#*:}"
        else
            source="$ref"
            target="$ref"
        fi
        push_and_verify "$PROJECT_ROOT" "$source" "$target" parent
    done
}

usage() {
    cat <<'EOF'
Usage: ./push_all_repos.sh [--check|--main-only|--subs-only]

  --check       Verify SSH remotes, branches, clean worktrees and remote SHAs.
  --main-only   Push the parent only; refuses stale parent gitlinks.
  --subs-only   Push nested repositories only.
  (no option)   Push nested repositories first, then the parent repository.

The SSH key is GEM5_SSH_KEY or ~/.ssh/id_ed25519_miuzujia2018_stack.
EOF
}

case "${1:-}" in
    "") ;;
    --check) MODE="check" ;;
    --main-only) SUBMODULES_ENABLED=0 ;;
    --subs-only) SUBMODULES_ENABLED=1 ;;
    --help|-h) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
esac

ensure_ssh_key
exec > >(tee -a "$LOG_FILE") 2>&1
say "Mode: $MODE; SSH host alias: $GITHUB_HOST; SSH key: $SSH_KEY"

if [[ "$SUBMODULES_ENABLED" == 1 && "${1:-}" != --main-only ]]; then
    for entry in "${SUBMODULES[@]}"; do
        process_submodule "$entry"
    done
fi

if [[ "${1:-}" != --subs-only ]]; then
    process_main
fi

say "Backup verification completed successfully. Log: $LOG_FILE"
