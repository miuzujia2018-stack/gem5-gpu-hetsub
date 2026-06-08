#!/usr/bin/env python
# parse_synth_stats.py — Parse stats.txt from synthetic traffic runs into CSV

import os, sys, csv, glob

FIELDS = [
    'pattern', 'synthetic', 'injection_rate',
    'avg_latency', 'network_latency', 'queueing_latency',
    'flits_received', 'sim_ticks', 'throughput_flits_per_tick'
]

def parse_stats(stats_path):
    """Extract relevant fields from a stats.txt file."""
    d = {}
    with open(stats_path) as f:
        for line in f:
            line = line.strip()
            # Parse key-value stats lines
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
            elif 'sim_ticks' in line and 'system.' not in line:
                parts = line.split()
                if parts[0] == 'sim_ticks':
                    d['sim_ticks'] = parts[1]
    return d

def main(outbase):
    results = []
    for stats_file in sorted(glob.glob(os.path.join(outbase, '*/inj_*/stats.txt'))):
        rel = os.path.relpath(stats_file, outbase)
        parts = rel.split(os.sep)
        pattern_name = parts[0]
        inj_str = parts[1]  # inj_0.10
        inj_rate = inj_str.replace('inj_', '')

        # Map pattern name to synthetic code
        pattern_map = {'uniform_random': 0, 'bit_reverse': 1, 'transpose': 2}
        synthetic = pattern_map.get(pattern_name, -1)

        d = parse_stats(stats_file)
        if not d:
            print "  WARN: no data in %s" % stats_file
            continue

        # Calculate throughput (flits per tick)
        try:
            flits = float(d.get('flits_received', 0))
            sim_ticks = float(d.get('sim_ticks', 1))
            d['throughput_flits_per_tick'] = "%.8f" % (flits / sim_ticks)
        except (ValueError, ZeroDivisionError):
            d['throughput_flits_per_tick'] = '0'

        row = {
            'pattern': pattern_name,
            'synthetic': str(synthetic),
            'injection_rate': inj_rate,
            'avg_latency': d.get('avg_latency', 'nan'),
            'network_latency': d.get('network_latency', 'nan'),
            'queueing_latency': d.get('queueing_latency', 'nan'),
            'flits_received': d.get('flits_received', '0'),
            'sim_ticks': d.get('sim_ticks', '0'),
            'throughput_flits_per_tick': d.get('throughput_flits_per_tick', '0'),
        }
        results.append(row)
        print "  %-20s inj=%5s  lat=%8s  thr=%s" % (
            row['pattern'], row['injection_rate'],
            row['avg_latency'], row['throughput_flits_per_tick'])

    # Sort by pattern, then injection rate
    results.sort(key=lambda r: (r['pattern'], float(r['injection_rate'])))

    csv_path = os.path.join(outbase, 'results.csv')
    with open(csv_path, 'w') as f:
        writer = csv.DictWriter(f, fieldnames=FIELDS)
        writer.writeheader()
        for row in results:
            writer.writerow(row)

    print ""
    print "  CSV written: %s (%d rows)" % (csv_path, len(results))

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print "Usage: %s <m5out/synth/>" % sys.argv[0]
        sys.exit(1)
    main(sys.argv[1])
