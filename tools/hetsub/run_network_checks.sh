#!/usr/bin/env bash
set -Eeuo pipefail
# Server-only compatibility entrypoint for the HetSub functional network case
# matrix.  The old Docker implementation is preserved under
# gem5-unified/manifests/legacy-specialized-20261028/.
ROOT="$(cd -P -- "$(dirname -- "${BASH_SOURCE[0]}")/../../../gem5-unified" && pwd)"
export GEM5_IMAGE="${GEM5_IMAGE:-localhost/gem5gpu-standby:20261027}"
export GEM5_SERVER_MODE=1
# Plain ssh does not propagate arbitrary environment to the remote shell, so
# forward the research overrides the legacy script accepted through `env`.
cmd="env"
for var in HETSUB_TEST_TAG HETSUB_TEST_CASES; do
  if [[ -n "${!var:-}" ]]; then
    cmd+=" $(printf '%q' "$var=${!var}")"
  fi
done
cmd+=" bash /home/siat/gem5-gpu-hetsub/tools/hetsub/run_network_checks.server.sh"
exec "$ROOT/scripts/server-command.sh" hetsub bash -c "$cmd"
