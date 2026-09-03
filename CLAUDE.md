# CLAUDE.md

This file provides guidance to Claude Code when working in this repository.

## Project Overview

**gem5-gpu** — a heterogeneous CPU-GPU simulation framework integrating:
- **gem5**: Modular system architecture simulator
- **GPGPU-Sim**: Cycle-level GPU functional/timing simulator
- **Ruby memory system**: Coherent cache hierarchy and interconnect (garnet/flexible-pipeline)

### Primary Objective

**XY Dimension-Ordered Routing (DOR) baseline** for 8x8 Mesh NoC in `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`. This is a cleanroom fork of gem5-gpu-bak that replaces MVPP_MGC_PSO with pure XY DOR to serve as a performance comparison baseline.

XY routing: route X dimension first (East/West), then Y dimension (North/South). Deterministic, deadlock-free, minimal-path.

## Dual-Agent Workflow Contract

When `.ai/tasks/TASK.md` exists, treat it as the active execution spec.

Execution rules:
- Follow `.ai/tasks/TASK.md` for the goal, file scope, acceptance criteria, and test commands.
- The task file overrides the default working-directory focus below when they conflict.
- Write execution results to `.ai/reports/REPORT.md`.
- Do not edit `.ai/reviews/REVIEW.md`.
- Escalate if the task spec and repo state disagree.

Verification rules:
- Use the verification commands required by the task file.
- The default `./docker_build_and_test_j64.sh` requirement below still applies when you change simulator source files or when the task does not define a narrower verification plan.

## Behavioral Guidelines

**Tradeoff:** These guidelines bias toward caution over speed. For trivial tasks, use judgment.

### 1. Think Before Coding

**Don't assume. Don't hide confusion. Surface tradeoffs.**

Before implementing:
- State your assumptions explicitly. If uncertain, ask.
- If multiple interpretations exist, present them — don't pick silently.
- If a simpler approach exists, say so. Push back when warranted.
- If something is unclear, stop. Name what's confusing. Ask.

### 2. Simplicity First

**Minimum code that solves the problem. Nothing speculative.**

- No features beyond what was asked.
- No abstractions for single-use code.
- No "flexibility" or "configurability" that wasn't requested.
- No error handling for impossible scenarios.
- If you write 200 lines and it could be 50, rewrite it.

Ask yourself: "Would a senior engineer say this is overcomplicated?" If yes, simplify.

### 3. Surgical Changes

**Touch only what you must. Clean up only your own mess.**

When editing existing code:
- Don't "improve" adjacent code, comments, or formatting.
- Don't refactor things that aren't broken.
- Match existing style, even if you'd do it differently.
- If you notice unrelated dead code, mention it — don't delete it.

When your changes create orphans:
- Remove imports/variables/functions that YOUR changes made unused.
- Don't remove pre-existing dead code unless asked.

The test: Every changed line should trace directly to the user's request.

### 4. Goal-Driven Execution

**Define success criteria. Loop until verified.**

Transform tasks into verifiable goals:
- "Add validation" → "Write tests for invalid inputs, then make them pass"
- "Fix the bug" → "Write a test that reproduces it, then make it pass"
- "Refactor X" → "Ensure tests pass before and after"

For multi-step tasks, state a brief plan:
```
1. [Step] → verify: [check]
2. [Step] → verify: [check]
3. [Step] → verify: [check]
```

Strong success criteria let you loop independently. Weak criteria ("make it work") require constant clarification.

---

**These guidelines are working if:** fewer unnecessary changes in diffs, fewer rewrites due to overcomplication, and clarifying questions come before implementation rather than after mistakes.

## Build System (Docker)

All compilation and testing runs in Docker container **`gem5gpu-dev`** (image `myubuntu14:latest`).

**IMPORTANT**: This system requires `sudo docker`. The container must be running before use:
```bash
sudo docker start gem5gpu-dev    # if stopped
```

### Mandatory: Build + Test After Changes

**After ANY code change to flexible-pipeline/ (or other source files), you MUST run:**

```bash
./docker_build_and_test_j64.sh
```

This compiles gem5.opt (-j64) AND runs both benchmarks (backprop + kmeans). Never push or declare a task complete without a passing run. If the script fails, fix the issue and rerun before proceeding.

### What the script does

1. `scons build/X86_VI_hammer_GPU/gem5.opt` inside the container
2. `./run.sh both` — backprop + kmeans benchmarks

### Critical Runtime Requirements

**Two fixes are essential for simulation to work:**

1. **Absolute path for `-c`**: Must use absolute path to the benchmark binary. Relative paths cause `_dl_get_origin` assertion failure in the simulated process's libc (gem5 SE mode returns relative path from `readlink("/proc/self/exe")`, but glibc requires it to start with `/`).

2. **CUDA environment variables**: `ptxas` must be in PATH, otherwise GPGPU-Sim PTX loader calls `exit(1)`. Set all three:
   ```bash
   export CUDAHOME=/usr/local/cuda/cuda
   export PATH=/usr/local/cuda/cuda/bin:$PATH
   export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
   ```

### Manual commands (inside container)

```bash
# Compile
cd /home/siat/gem5-gpu-xy/gem5
export CUDAHOME=/usr/local/cuda/cuda
scons build/X86_VI_hammer_GPU/gem5.opt --default=X86 \
    EXTRAS=../gem5-gpu/src:../gpgpu-sim/ PROTOCOL=VI_hammer GPGPU_SIM=True -j64

# Test backprop (8x8 mesh, flexible pipeline)
export CUDAHOME=/usr/local/cuda/cuda
export PATH=/usr/local/cuda/cuda/bin:$PATH
export LD_LIBRARY_PATH=/usr/local/cuda/cuda/lib64
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /tmp/test \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c /home/siat/gem5-gpu-xy/benchmarks/rodinia/backprop/gem5_fusion_backprop -o "16"

# Test kmeans
./gem5/build/X86_VI_hammer_GPU/gem5.opt -d /tmp/test \
    gem5-gpu/configs/se_fusion.py --garnet-network=flexible \
    -c /home/siat/gem5-gpu-xy/benchmarks/rodinia/kmeans/gem5_fusion_kmeans \
    -o "-i /home/siat/gem5-gpu-xy/kmeans_input.txt"
```

## Working Directory Constraints

- **Primary working directory**: `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`
- **Allowed**: Modify .cc/.hh files in flexible-pipeline, create new files there
- **Prohibited**: Modify files outside flexible-pipeline, create subdirectories, create .bak files

## Interface Preservation Rules

Existing public method signatures must NOT be modified. Extend by adding new methods/members, not changing existing ones.

Key classes and their core interfaces:

```cpp
// Router (Router.hh) - MUST preserve:
int getRoute(NetDest destination);
int getRoutePSO(NetDest destination);
int getRouteCollaborative(NetDest destination);
void routeCompute(flit *m_flit, int inport);
void addInPort(NetworkLink *in_link);
void addOutPort(NetworkLink *out_link, const NetDest& routing_table_entry, int link_weight);
void wakeup();
uint32_t get_id() const;

// PSOAlgorithm (PSOAlgorithm.hh) - MUST preserve:
void initializePSO();
int getRoutePSO(NetDest destination);
double calculateMultiObjectiveFitness(const PacketParticle& packet);
void updateParticlePosition(Particle& particle, int src_node, int dest_node);
```

Existing struct members in `Particle`, `PacketParticle` must also be preserved. Add new fields but don't remove/rename existing ones.

## Current Implementation State

### Topology: 8x8 Mesh (64 nodes)

Key constants in `Router.hh`:
- `GlobalGraph::MESH_SIZE = 8`
- `GlobalGraph::TOTAL_NODES = 64`
- `GlobalGraph::TOTAL_EDGES = 224`

### Critical Bug Fixes Applied

1. **`Set.hh:71`** — `INDEX_SHIFT = LONG_BITS >= 64 ? 6 : 5` (was `LONG_BITS == 64 ? 6 : 5`). Fixes bit overflow for MachineTypes with >32 controllers.

2. **`Router.hh/cc`** — `routingTableHasDest()` + `m_routing_table_mids`: Bypasses `NetDest::intersectionIsNotEmpty()` which only checks the first Set word. Pre-computes MachineID lists at `addOutPort()` time.

3. **`process.cc:407,455`** — gettid and tgkill syscall implementations for SE mode.

4. **`-c` absolute path requirement** — Benchmark binary path passed to `-c` must be absolute (e.g., `/home/siat/gem5-gpu-bak/benchmarks/...`). Relative paths cause `_dl_get_origin` assertion failure in simulated glibc during `readlink("/proc/self/exe")`.

5. **CUDA env vars for simulation** — Must export `CUDAHOME=/usr/local/cuda/cuda`, add `ptxas` to PATH, and set `LD_LIBRARY_PATH`. Without this, GPGPU-Sim PTX loader calls `exit(1)` when `ptxas` is not found.

### Flexible-Pipeline Components (24 files)

| File | Role |
|------|------|
| `Router.hh/cc` | Main router with XY DOR algorithm (PSO code retained but unused) |
| `PSOAlgorithm.hh/cc` | Particle Swarm Optimization engine (unused, kept for API compat) |
| `SwarmManager.hh/cc` | Multi-swarm collaboration (unused, kept for API compat) |
| `PerformanceAnalyzer.hh/cc` | Performance monitoring and power statistics |
| `NetworkUtilities.hh/cc` | Topology management and utilities |
| `GarnetNetwork.hh/cc` | Network controller, topology, direction-to-port mapping registration |

### Routing Decision Hierarchy

```
1. getRouteXY() → XY Dimension-Ordered Routing (primary)
2. Table Routing (fallback, if XY port mapping fails)
```

### XY Direction-to-Port Mapping Architecture

`getRouteXY(src, dest)` returns a logical direction (0=N, 1=E, 2=S, 3=W, -1=local), but physical output port indices are assigned by `addOutPort()` in a fixed order (external links first, then internal links sorted by dest switch ID). The `m_direction_to_port[5]` array bridges this gap:

- **`GarnetNetwork::makeOutLink()`** — registers external link as direction 4 (local)
- **`GarnetNetwork::makeInternalLink()`** — computes XY direction from `(dx, dy)` between src/dest router IDs and registers via `setDirectionPort()`
- **`Router::getRoute()`** — calls `getRouteXY()`, maps result through `m_direction_to_port[]`, verifies port is in routing table, falls back to table scan on failure

### Coding Conventions

- **Naming**: `snake_case` for variables, `CamelCase` for classes
- **Members**: `m_` prefix (e.g., `m_router_ptr`)
- **Statics**: `s_` prefix (e.g., `s_global_graph`)
- **C++11**: smart pointers, `auto`, range-based for, lambdas, move semantics

## Key Architecture

```
CPU Application (CUDA Runtime)
        ↓
   CudaGPU Interface
        ↓
   GPGPU-Sim Engine ←→ Ruby Memory System
        ↓                     ↓
   GPU Cores/Shaders     Cache Hierarchy (VI_hammer protocol)
        ↓                     ↓
   GPU Memory System ←→ CPU Memory System
```

### Integration Points

- `gem5-gpu/src/gpu/gpgpu-sim/cuda_gpu.hh` — CudaGPU main entry point
- `gem5-gpu/src/mem/protocol/` — VI_hammer coherence protocol
- `gem5-gpu/configs/se_fusion.py` — Primary simulation config
- `gpgpu-sim/` — GPU timing models, CUDA functional sim, GPUWattch power

### Benchmarks

Rodinia suite in `benchmarks/rodinia/`: backprop, bfs, cfd, kmeans, etc.
Build with `make -f Makefile.gem5-fusion`.

## Push Workflow (Mandatory After Successful Build+Test)

**After any code change passes compilation AND benchmark tests, you MUST push before starting the next modification.** This ensures each change is versioned independently and can be rolled back cleanly.

### Step 1: Document what was changed

Before pushing, write a clear summary of:
- Which files were modified
- Why each modification was made
- What the expected effect is (e.g., routing behavior change, bug fix)

### Step 2: Run push_all_repos.sh

```bash
cd /home/siat/gem5-gpu-xy
./push_all_repos.sh
```

This pushes:
- **Main repo** (`gem5-gpu-xy`) → gitee `miuzujia/gem5-gpu-xy`, branch `gem5-gpu-xy`
- **All 5 submodules** (`gem5`, `gem5-gpu`, `gpgpu-sim`, `Graphite`, `benchmarks`) → gitee, branch `gem5-gpu-xy`

### Step 3: Verify

Check gitee for all 6 repositories showing the latest commits on branch `gem5-gpu-xy`.

### Branch isolation

- `gem5-gpu-bak` uses `master` branch on gitee
- `gem5-gpu-xy` uses `gem5-gpu-xy` branch everywhere
- These branches are **completely independent** — pushing gem5-gpu-xy will never affect gem5-gpu-bak

### Repository URLs

| Repo | Gitee URL | Branch |
|------|-----------|--------|
| Main | `https://gitee.com/miuzujia/gem5-gpu-xy` | `gem5-gpu-xy` |
| gem5 | `https://gitee.com/miuzujia/gem5` | `gem5-gpu-xy` |
| gem5-gpu | `https://gitee.com/miuzujia/gem5-gpu` | `gem5-gpu-xy` |
| gpgpu-sim | `https://gitee.com/miuzujia/gpgpu-sim` | `gem5-gpu-xy` |
| Graphite | `https://gitee.com/miuzujia/graphite` | `gem5-gpu-xy` |
| benchmarks | `https://gitee.com/miuzujia/benchmarks` | `gem5-gpu-xy` |
