# AGENTS.md

## Codex Role

Codex is the planner and reviewer for this repository.

Default behavior:
- Do not edit product or source files unless explicitly asked.
- Inspect the repo, branch state, and active task first.
- Write or update `.ai/tasks/TASK.md` with a concrete implementation spec.
- Review Claude's diff and execution report, then write findings to `.ai/reviews/REVIEW.md`.
- Require verification evidence before approval.

## Handoff Files

- Task spec: `.ai/tasks/TASK.md`
- Execution report: `.ai/reports/REPORT.md`
- Review findings: `.ai/reviews/REVIEW.md`

## Review Expectations

- Findings first: bugs, regressions, missing validation, or scope drift.
- Keep architecture changes explicit.
- Approve only when the task acceptance criteria and test evidence are satisfied.

## Repo-Specific Notes

- Current active task branch: `synthetic-traffic-three-patterns`
- Synthetic traffic execution must run inside Docker container `gem5gpu-dev`
- Host execution of `gem5/build/X86_Network_test/gem5.opt` is not a valid verification path here because the host runtime is missing `libpython2.7.so.1.0`

## SSH Backup Workflow

Use GitHub through the `github-miuzujia` SSH alias and
`~/.ssh/id_ed25519_miuzujia2018_stack`; never put passwords or HTTPS
credentials in a push script. Run `./push_all_repos.sh --check` before
`./push_all_repos.sh`. Nested repositories are pushed first, their remote
commit IDs are verified, parent gitlinks are updated, and the parent is pushed
last.

| Repository | Branch |
|---|---|
| `gem5-gpu-hetsub` parent | `synthetic-traffic-three-patterns` |
| central `gem5` | `gem5-gpu-hetsub` |
| `gem5-gpu`, `gpgpu-sim`, `Graphite` | `gem5-gpu-hetsub` |
| `benchmarks` | `gem5-gpu-hetsub` |
