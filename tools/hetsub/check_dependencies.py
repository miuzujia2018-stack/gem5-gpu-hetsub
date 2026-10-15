#!/usr/bin/env python3
"""Exhaust the configured 64x64 routes and check their channel dependencies.

This checks NoC channel/relay resource dependencies, not Ruby protocol-level
dependencies or hardware timing. A frozen bypass is one exclusive circuit;
its intermediate crossbars have no packet buffer or arbitration context.
"""
import argparse
import configparser
import json
from collections import defaultdict, deque
from pathlib import Path

from insert_shortcuts import hilbert_order


def check(config):
    cfg = configparser.ConfigParser()
    cfg.read(config)
    net = 'system.ruby.network'
    mode = cfg.get(net, 'het_mode')
    if mode not in ('dual', 'static'):
        raise ValueError('Dependency checker applies to the HetSub data path')
    order = hilbert_order()
    ranks = {tile: rank for rank, tile in enumerate(order)}
    line_edges = set()
    for name in cfg.get(net, 'het_line_links').split():
        src, dst = (cfg.getint(name, k) for k in ('het_src_tile', 'het_dst_tile'))
        if src >= 0 and dst >= 0:
            line_edges.add((src, dst))
    assert len(line_edges) == 126
    mesh_edges = set()
    for name in cfg.get(net, 'int_links').split():
        a, b = (cfg.getint(cfg.get(name, k), 'router_id') for k in ('node_a', 'node_b'))
        assert abs(a//8-b//8) + abs(a%8-b%8) == 1
        mesh_edges.update(((a, b), (b, a)))
    assert len(mesh_edges) == 224
    shortcuts = {}
    encoded = [int(v) for v in cfg.get(net, 'het_shortcut_paths').split()]
    for i in range(0, len(encoded), 3):
        src, mid, dst = encoded[i:i+3]
        assert src not in shortcuts
        shortcuts[src] = dst
        physical = [src, dst] if mid < 0 else [src, mid, dst]
        assert all(edge in mesh_edges for edge in zip(physical, physical[1:]))
    if mode == 'dual':
        assert not shortcuts

    graph = defaultdict(set)
    paths = 0
    for plane in ('L', 'M') if mode == 'dual' else ('L',):
        for src in range(64):
            for dst in range(64):
                resources = []
                tile = src
                visited = set()
                while tile != dst:
                    assert tile not in visited, ('route loop', src, dst, tile)
                    visited.add(tile)
                    if plane == 'L':
                        end = shortcuts.get(tile)
                        c, d = ranks[tile], ranks[dst]
                        e = ranks[end] if end is not None else c
                        if c < e <= d or d <= e < c:
                            # L output VC -> serializer -> frozen circuit ->
                            # deserializer -> next L output VC.
                            resources.extend((kind, tile, end) for kind in
                                             ('relay_in', 'serialize', 'circuit', 'deserialize'))
                            tile = end
                            continue
                        nxt = order[c + (1 if d > c else -1)]
                        assert (tile, nxt) in line_edges
                    else:
                        # Exact X-then-Y order used by HetSub M getRoute().
                        if tile % 8 != dst % 8:
                            nxt = tile + (1 if dst % 8 > tile % 8 else -1)
                        else:
                            nxt = tile + (8 if dst > tile else -8)
                        assert (tile, nxt) in mesh_edges
                    resources.append((plane, tile, nxt))
                    tile = nxt
                for node in resources:
                    graph[node]
                for a, b in zip(resources, resources[1:]):
                    graph[a].add(b)
                paths += 1
    incoming = {node: 0 for node in graph}
    for targets in graph.values():
        for target in targets:
            incoming[target] += 1
    ready = deque(node for node, degree in incoming.items() if degree == 0)
    removed = 0
    while ready:
        node = ready.popleft()
        removed += 1
        for target in graph[node]:
            incoming[target] -= 1
            if incoming[target] == 0:
                ready.append(target)
    assert removed == len(graph), 'cyclic channel/relay dependency'
    return dict(mode=mode, paths=paths, resources=len(graph),
                dependencies=sum(map(len, graph.values())), acyclic=True,
                scope='NoC routes, per-vnet isolation; excludes Ruby protocol dependencies')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('config', type=Path)
    args = parser.parse_args()
    print(json.dumps(check(args.config), indent=2))
