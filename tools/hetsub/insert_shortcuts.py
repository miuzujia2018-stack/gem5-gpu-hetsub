#!/usr/bin/env python3
"""Offline HetSub Algorithm 2: hierarchical center candidates on an 8x8 HSC.

Input is an independently collected source-tile,destination-tile,bytes profile.
The result is a frozen configuration, not an online reconfiguration policy.
"""
import argparse
import csv
import json
from pathlib import Path


def hilbert_order():
    order = []
    for distance in range(64):
        x, y, t = 0, 0, distance
        for scale in (1, 2, 4):
            rx = (t // 2) & 1
            ry = (t ^ rx) & 1
            if ry == 0:
                if rx:
                    x, y = scale - 1 - x, scale - 1 - y
                x, y = y, x
            x += scale * rx
            y += scale * ry
            t //= 4
        order.append(y * 8 + x)
    return order


def candidates(profile):
    ranks = {tile: rank for rank, tile in enumerate(hilbert_order())}
    # Higher-level U parts first. The lowest 2x2 level is intentionally absent.
    for level, side in enumerate((8, 4), 1):
        half = side // 2
        for y in range(0, 8, side):
            for x in range(0, 8, side):
                children = []
                for dy in (0, half):
                    for dx in (0, half):
                        tiles = {r * 8 + c for r in range(y + dy, y + dy + half)
                                 for c in range(x + dx, x + dx + half)}
                        center_x = x + half - 1 if dx == 0 else x + half
                        center_y = y + half - 1 if dy == 0 else y + half
                        children.append((min(ranks[t] for t in tiles), tiles,
                                         center_y * 8 + center_x))
                children.sort()
                for i, (_, sources, source) in enumerate(children):
                    for j, (_, destinations, destination) in enumerate(children):
                        if abs(i - j) <= 1:
                            continue
                        flow = sum(profile.get((s, d), 0) for s in sources
                                   for d in destinations)
                        yield dict(level=level, src=source, dst=destination,
                                   flow_bytes=flow)


def physical_paths(src, dst):
    if src // 8 == dst // 8 or src % 8 == dst % 8:
        return [[src, dst]]
    return [[src, (src // 8) * 8 + dst % 8, dst],
            [src, (dst // 8) * 8 + src % 8, dst]]


def direction(a, b):
    if b // 8 == a // 8 and b == a + 1: return 'E'
    if b // 8 == a // 8 and b == a - 1: return 'W'
    if b == a + 8: return 'S'
    if b == a - 8: return 'N'
    raise ValueError('shortcut contains a non-adjacent physical segment')


def resources(path):
    if not 2 <= len(path) <= 3 or len(set(path)) != len(path):
        raise ValueError('shortcut must use one or two physical hops')
    inputs, outputs, edges = set(), set(), set()
    for index, tile in enumerate(path):
        incoming = 'L' if index == 0 else direction(tile, path[index - 1])
        outgoing = 'L' if index == len(path) - 1 else direction(tile, path[index + 1])
        inputs.add((tile, incoming))
        outputs.add((tile, outgoing))
        if index + 1 < len(path): edges.add((tile, path[index + 1]))
    return inputs, outputs, edges


def insert(profile, threshold, limit):
    if threshold < 0 or limit < 0:
        raise ValueError('threshold and limit must be nonnegative')
    selected, audit = [], []
    occupied_in, occupied_out, occupied_edges = set(), set(), set()
    for candidate in candidates(profile):
        row = dict(candidate)
        if candidate['flow_bytes'] <= threshold:
            row['reason'] = 'below_threshold'
        elif len(selected) >= limit:
            row['reason'] = 'limit'
        else:
            row['reason'] = 'conflict'
            for path in physical_paths(candidate['src'], candidate['dst']):
                incoming, outgoing, edges = resources(path)
                if (incoming & occupied_in or outgoing & occupied_out or
                        edges & occupied_edges):
                    continue
                selected.append(dict(candidate, path=path))
                occupied_in.update(incoming)
                occupied_out.update(outgoing)
                occupied_edges.update(edges)
                row['reason'] = 'selected'
                break
        audit.append(row)
    return selected, audit


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--profile', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--threshold-bytes', type=int, default=0)
    parser.add_argument('--limit', type=int, default=4,
                        help='maximum number of directed shortcuts')
    args = parser.parse_args()
    profile = {}
    with args.profile.open() as stream:
        for row in csv.DictReader(stream):
            s, d, count = int(row['src_tile']), int(row['dst_tile']), int(row['bytes'])
            if not (0 <= s < 64 and 0 <= d < 64 and count >= 0):
                raise ValueError('invalid profile row')
            profile[s, d] = profile.get((s, d), 0) + count
    links, audit = insert(profile, args.threshold_bytes, args.limit)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(dict(links=links), indent=2) + '\n')
    with args.output.with_suffix('.csv').open('w') as stream:
        writer = csv.DictWriter(stream,
            fieldnames=['level', 'src', 'dst', 'flow_bytes', 'reason'])
        writer.writeheader()
        writer.writerows(audit)
    print('Selected %d directed shortcuts from an offline profile' % len(links))


if __name__ == '__main__':
    main()
