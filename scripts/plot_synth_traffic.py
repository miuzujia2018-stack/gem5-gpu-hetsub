#!/usr/bin/env python3
# plot_synth_traffic.py — Generate latency/throughput vs load curves

from __future__ import print_function
import sys, os
import csv

try:
    import matplotlib
    matplotlib.use('Agg')
    import matplotlib.pyplot as plt
except ImportError:
    print("ERROR: matplotlib not available. Install: pip install matplotlib")
    sys.exit(1)

PATTERN_LABELS = {
    'uniform_random': 'Uniform Random',
    'bit_reverse': 'Bit Reverse',
    'transpose': 'Transpose',
}

PATTERN_MARKERS = {
    'uniform_random': 'o',
    'bit_reverse': 's',
    'transpose': '^',
}

def load_csv(csv_path):
    data = {}
    with open(csv_path) as f:
        for row in csv.DictReader(f):
            p = row['pattern']
            if p not in data:
                data[p] = {'inj': [], 'lat': [], 'thr': []}
            data[p]['inj'].append(float(row['injection_rate']))
            data[p]['lat'].append(float(row['network_latency']))
            data[p]['thr'].append(float(row['throughput_packets_per_cycle_per_node']))
    return data

def plot_latency(data, outdir):
    fig, ax = plt.subplots(figsize=(8, 5))
    for pattern in ['uniform_random', 'bit_reverse', 'transpose']:
        if pattern not in data:
            continue
        d = data[pattern]
        ax.plot(d['inj'], d['lat'],
                marker=PATTERN_MARKERS.get(pattern, 'x'),
                label=PATTERN_LABELS.get(pattern, pattern),
                linewidth=1.5, markersize=5)

    ax.set_xlabel('Injection Rate (packets/cycle/node)', fontsize=12)
    ax.set_ylabel('Network Latency (cycles)', fontsize=12)
    ax.set_title('Latency vs. Injection Load — 8x8 Mesh XY DOR', fontsize=13)
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)

    fpath = os.path.join(outdir, 'latency_vs_load.png')
    fig.savefig(fpath, dpi=150, bbox_inches='tight')
    print("  Saved: %s" % fpath)
    plt.close(fig)

def plot_throughput(data, outdir):
    fig, ax = plt.subplots(figsize=(8, 5))
    for pattern in ['uniform_random', 'bit_reverse', 'transpose']:
        if pattern not in data:
            continue
        d = data[pattern]
        ax.plot(d['inj'], d['thr'],
                marker=PATTERN_MARKERS.get(pattern, 'x'),
                label=PATTERN_LABELS.get(pattern, pattern),
                linewidth=1.5, markersize=5)

    ax.set_xlabel('Injection Rate (packets/cycle/node)', fontsize=12)
    ax.set_ylabel('Throughput (packets/cycle/node)', fontsize=12)
    ax.set_title('Throughput vs. Injection Load — 8x8 Mesh XY DOR', fontsize=13)
    ax.legend(fontsize=10)
    ax.grid(True, alpha=0.3)
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)

    fpath = os.path.join(outdir, 'throughput_vs_load.png')
    fig.savefig(fpath, dpi=150, bbox_inches='tight')
    print("  Saved: %s" % fpath)
    plt.close(fig)

def main():
    if len(sys.argv) < 2:
        print("Usage: %s <results.csv>" % sys.argv[0])
        sys.exit(1)

    csv_path = sys.argv[1]
    outdir = os.path.dirname(csv_path)

    data = load_csv(csv_path)
    if not data:
        print("ERROR: no data in %s" % csv_path)
        sys.exit(1)

    plot_latency(data, outdir)
    plot_throughput(data, outdir)
    print("  Plotting complete.")

if __name__ == '__main__':
    main()
