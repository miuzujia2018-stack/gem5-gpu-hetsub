# Task: HetSub-Inspired Logical Routing Overlay (Phase 1)

## Goal

Implement Phase 1 of a HetSub-inspired logical routing overlay on the existing 8x8 mesh
in `gem5/src/mem/ruby/network/garnet/flexible-pipeline/`.

Phase 1 delivers: Hilbert-curve-based greedy routing with XY DOR fallback.
Must be deadlock-free and pass backprop + kmeans benchmarks.

## Context

This is NOT a full HetSub architecture implementation. It is a **HetSub-inspired logical
routing overlay** on a single 8x8 mesh. The Hilbert curve provides a 1D ordering that
emulates the dual-line always-on subnetwork from HetSub, using the existing mesh physical links.

### Phase 1 Scope (this task)
- Hilbert curve ordering for 64 nodes (8x8)
- Greedy Hilbert-curve routing: at each hop, move to the neighbor whose Hilbert index is closest to dest
- XY DOR as guaranteed fallback
- Statistics counters for route mode usage
- Backprop + kmeans must pass

### Out of scope (Phase 2, 3)
- Congestion-aware subnetwork selection
- Logical shortcut paths
- Dynamic route mode switching based on buffer occupancy

## Deadlock Safety

Hilbert greedy routing is deadlock-free: each hop strictly decreases the Hilbert distance
to destination (total order 0..63), making cycles impossible.
XY DOR is deadlock-free: each hop strictly decreases Manhattan distance.
Route mode is recomputed at each hop from (current_node, dest), but both algorithms are
individually deadlock-free.

## Files to Modify

- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.hh` — add Hilbert tables, new method declarations
- `gem5/src/mem/ruby/network/garnet/flexible-pipeline/Router.cc` — implement Hilbert routing, modify getRoute()

## Acceptance Criteria

1. Build succeeds inside Docker: `scons build/X86_VI_hammer_GPU/gem5.opt`
2. Backprop benchmark completes successfully
3. Kmeans benchmark completes successfully
4. No deadlocks, no crashes, no assertion failures
5. HetSub routing statistics appear in stats output

## Test Commands

```bash
./docker_build_and_test_j64.sh
```

## Do Not

- Do not modify files outside flexible-pipeline/
- Do not modify existing public method signatures
- Do not remove PSO/legacy code
- Do not claim this implements the full HetSub architecture
