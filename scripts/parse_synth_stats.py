#!/usr/bin/env python3
# parse_synth_stats.py — Parse stats.txt from synthetic traffic runs into CSV

from __future__ import print_function
import os, sys, csv, glob

FIELDS = [
    'pattern', 'synthetic', 'injection_rate',
    'avg_latency', 'network_latency', 'queueing_latency',
    'flits_received', 'packets_received', 'sim_ticks',
    'throughput_flits_per_tick', 'throughput_packets_per_cycle_per_node'
]

NUM_NODES = 64
# Network_test maps vnet0/vnet1 to control packets and vnet2 to data packets.
# With the default 16-byte flit size, control packets are 1 flit and data
# packets are 5 flits. This converts Garnet flit counters back to packets.
VNET_FLITS_PER_PACKET = [1.0, 1.0, 5.0]

def parse_flits_vector(line):
    counts = []
    for field in line.split('|')[1:]:
        parts = field.strip().split()
        if not parts:
            continue
        try:
            counts.append(float(parts[0]))
        except ValueError:
            pass
    return counts

def parse_stats(stats_path):
    """Extract relevant fields from a stats.txt file."""
    d = {}
    with open(stats_path, encoding='utf-8', errors='replace') as f:
        for line in f:
            line = line.strip()
            if 'system.ruby.network.average_latency ' in line and 'average_vnet' not in line and 'average_vqueue' not in line:
                parts = line.split()
                d['avg_latency'] = parts[1]
            elif 'system.ruby.network.average_network_latency ' in line:
                parts = line.split()
                d['network_latency'] = parts[1]
            elif 'system.ruby.network.average_queueing_latency ' in line:
                parts = line.split()
                d['queueing_latency'] = parts[1]
            elif 'system.ruby.network.flits_received::total' in line:
                parts = line.split()
                d['flits_received'] = parts[1]
            elif line.startswith('system.ruby.network.flits_received '):
                d['flits_received_by_vnet'] = parse_flits_vector(line)
            elif 'sim_ticks' in line and 'system.' not in line:
                parts = line.split()
                if parts[0] == 'sim_ticks':
                    d['sim_ticks'] = parts[1]
    return d

def main(outbase):
    results = []
    KNOWN_PATTERNS = {'uniform_random', 'bit_reverse', 'transpose'}
    for stats_file in sorted(glob.glob(os.path.join(outbase, '*/inj_*/stats.txt'))):
        rel = os.path.relpath(stats_file, outbase)
        parts = rel.split(os.sep)
        pattern_name = parts[0]

        # Skip stale directories not matching current pattern names
        if pattern_name not in KNOWN_PATTERNS:
            print("  SKIP (unknown pattern): %s" % stats_file)
            continue

        inj_str = parts[1]
        inj_rate = inj_str.replace('inj_', '')

        pattern_map = {'uniform': 0, 'bit_reverse': 1, 'transpose': 2, 'uniform_random': 0}
        synthetic = pattern_map.get(pattern_name, -1)

        d = parse_stats(stats_file)
        if not d:
            print("  WARN: no data in %s" % stats_file)
            continue

        try:
            flits = float(d.get('flits_received', 0))
            sim_ticks = float(d.get('sim_ticks', 1))
            d['throughput_flits_per_tick'] = "%.8f" % (flits / sim_ticks)

            vnet_flits = d.get('flits_received_by_vnet', [])
            packets = 0.0
            for idx, flits_per_packet in enumerate(VNET_FLITS_PER_PACKET):
                if idx < len(vnet_flits):
                    packets += vnet_flits[idx] / flits_per_packet
            if packets == 0.0:
                packets = flits
            d['packets_received'] = "%.8f" % packets
            d['throughput_packets_per_cycle_per_node'] = "%.8f" % (
                packets / sim_ticks / NUM_NODES)
        except (ValueError, ZeroDivisionError):
            d['throughput_flits_per_tick'] = '0'
            d['packets_received'] = '0'
            d['throughput_packets_per_cycle_per_node'] = '0'

        row = {
            'pattern': pattern_name,
            'synthetic': str(synthetic),
            'injection_rate': inj_rate,
            'avg_latency': d.get('avg_latency', 'nan'),
            'network_latency': d.get('network_latency', 'nan'),
            'queueing_latency': d.get('queueing_latency', 'nan'),
            'flits_received': d.get('flits_received', '0'),
            'packets_received': d.get('packets_received', '0'),
            'sim_ticks': d.get('sim_ticks', '0'),
            'throughput_flits_per_tick': d.get('throughput_flits_per_tick', '0'),
            'throughput_packets_per_cycle_per_node': d.get(
                'throughput_packets_per_cycle_per_node', '0'),
        }
        results.append(row)
        print("  %-20s inj=%5s  net_lat=%8s  thr=%s" % (
            row['pattern'], row['injection_rate'],
            row['network_latency'],
            row['throughput_packets_per_cycle_per_node']))

    results.sort(key=lambda r: (r['pattern'], float(r['injection_rate'])))

    csv_path = os.path.join(outbase, 'results.csv')
    with open(csv_path, 'w') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        for row in results:
            writer.writerow(row)

    print("")
    print("  CSV written: %s (%d rows)" % (csv_path, len(results)))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Usage: %s <m5out/synth/>" % sys.argv[0])
        sys.exit(1)
    main(sys.argv[1])
