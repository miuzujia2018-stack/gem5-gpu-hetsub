#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""
generate_results_csv.py - gem5-gpu Performance Results CSV Generator

This script parses gem5 statistics output and generates a CSV report
with key performance metrics for MVPP_MGC_PSO routing algorithm analysis.

Usage:
    python3 generate_results_csv.py <stats_file> [output_csv]

Example:
    python3 generate_results_csv.py /home/siat/test/stats.txt results_20251105_143000.csv
"""

import sys
import re
import csv
from datetime import datetime
from collections import defaultdict


class Gem5StatsParser:
    """Parser for gem5 statistics output files"""

    def __init__(self, stats_file):
        self.stats_file = stats_file
        self.stats = {}

    def parse(self):
        """Parse the stats.txt file and extract key metrics"""
        try:
            with open(self.stats_file, 'r') as f:
                for line in f:
                    line = line.strip()
                    if not line or line.startswith('#') or line.startswith('-'):
                        continue

                    # Parse key-value pairs: stat_name value # comment
                    match = re.match(r'([^\s]+)\s+([^\s#]+)', line)
                    if match:
                        stat_name = match.group(1)
                        stat_value = match.group(2)
                        self.stats[stat_name] = stat_value

        except FileNotFoundError:
            print(f"Error: Statistics file not found: {self.stats_file}")
            sys.exit(1)
        except Exception as e:
            print(f"Error parsing statistics file: {e}")
            sys.exit(1)

    def get_stat(self, key, default='N/A'):
        """Get a statistic value by key"""
        return self.stats.get(key, default)

    def get_mvpp_stats(self):
        """Extract MVPP_MGC_PSO routing algorithm statistics"""
        mvpp_stats = {}

        # Find all MVPP-related statistics
        for key, value in self.stats.items():
            if 'mvpp_mgc_pso' in key.lower():
                # Extract the metric name (last part after the last dot)
                metric_name = key.split('.')[-1]
                mvpp_stats[metric_name] = value

        return mvpp_stats


class ResultsCSVGenerator:
    """Generate CSV report from parsed statistics"""

    def __init__(self, parser, test_name='unknown'):
        self.parser = parser
        self.test_name = test_name
        self.timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')

    def generate_csv(self, output_file=None):
        """Generate comprehensive CSV report"""

        if output_file is None:
            output_file = f'results_{self.timestamp}.csv'

        # Prepare data rows
        rows = []

        # ==== General System Metrics ====
        rows.append(['=== General System Metrics ===', ''])
        rows.append(['Timestamp', self.timestamp])
        rows.append(['Test Name', self.test_name])
        rows.append(['Simulation Time (seconds)', self.parser.get_stat('sim_seconds')])
        rows.append(['Simulation Ticks', self.parser.get_stat('sim_ticks')])
        rows.append(['Host Execution Time (seconds)', self.parser.get_stat('host_seconds')])
        rows.append(['Simulated Instructions', self.parser.get_stat('sim_insts')])
        rows.append(['Simulated Ops', self.parser.get_stat('sim_ops')])
        rows.append(['Host Instruction Rate (inst/s)', self.parser.get_stat('host_inst_rate')])
        rows.append(['', ''])

        # ==== MVPP_MGC_PSO Routing Algorithm Metrics ====
        rows.append(['=== MVPP_MGC_PSO Routing Algorithm Metrics ===', ''])

        # Find first router node with MVPP stats
        mvpp_prefix = None
        for key in self.parser.stats.keys():
            if 'mvpp_mgc_pso_routing_count' in key:
                mvpp_prefix = key.replace('.mvpp_mgc_pso_routing_count', '')
                break

        if mvpp_prefix:
            rows.append(['Router Node', mvpp_prefix])
            rows.append(['MVPP_MGC_PSO Routing Count',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_routing_count')])
            rows.append(['Traditional Routing Count',
                        self.parser.get_stat(f'{mvpp_prefix}.traditional_routing_count')])
            rows.append(['Total Routing Count',
                        self.parser.get_stat(f'{mvpp_prefix}.total_routing_count')])
            rows.append(['MVPP_MGC_PSO Routing Time (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_routing_time')])
            rows.append(['Traditional Routing Time (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.traditional_routing_time')])
            rows.append(['Total Routing Time (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.total_routing_time')])
            rows.append(['MVPP_MGC_PSO Power Consumption (μW·s)',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_power_consumption')])
            rows.append(['Traditional Power Consumption (μW·s)',
                        self.parser.get_stat(f'{mvpp_prefix}.traditional_power_consumption')])
            rows.append(['Total Power Consumption (μW·s)',
                        self.parser.get_stat(f'{mvpp_prefix}.total_power_consumption')])

            # Routing delay statistics
            rows.append(['MVPP_MGC_PSO Avg Routing Delay (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_routing_delay::mean')])
            rows.append(['MVPP_MGC_PSO Routing Delay Std Dev (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_routing_delay::stdev')])
            rows.append(['MVPP_MGC_PSO Routing Delay Geomean (ticks)',
                        self.parser.get_stat(f'{mvpp_prefix}.mvpp_mgc_pso_routing_delay::gmean')])
        else:
            rows.append(['Router Node', 'No MVPP statistics found'])

        rows.append(['', ''])

        # ==== Network Link Utilization ====
        rows.append(['=== Network Link Utilization (Top 10 Links) ===', ''])
        if mvpp_prefix:
            link_utils = []
            for i in range(24):  # Check first 24 links
                key = f'{mvpp_prefix}.link_utilization::{i}'
                if key in self.parser.stats:
                    util = self.parser.get_stat(key)
                    if util != '0':
                        link_utils.append((i, int(util)))

            # Sort by utilization (descending)
            link_utils.sort(key=lambda x: x[1], reverse=True)

            for idx, (link_id, util) in enumerate(link_utils[:10], 1):
                rows.append([f'Link {link_id} Utilization', str(util)])

        rows.append(['', ''])

        # ==== Memory System Metrics ====
        rows.append(['=== Memory System Metrics ===', ''])
        rows.append(['Memory Bytes Read', self.parser.get_stat('system.mem_ctrls0.bytes_read::total')])
        rows.append(['Memory Bytes Written', self.parser.get_stat('system.mem_ctrls0.bytes_written::total')])
        rows.append(['Memory Read Bandwidth (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_read::total')])
        rows.append(['Memory Write Bandwidth (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_write::total')])
        rows.append(['Memory Total Bandwidth (bytes/s)', self.parser.get_stat('system.mem_ctrls0.bw_total::total')])
        rows.append(['Avg Memory Access Latency (cycles)', self.parser.get_stat('system.mem_ctrls0.avgMemAccLat')])
        rows.append(['', ''])

        # ==== Power Metrics ====
        rows.append(['=== Power Metrics ===', ''])
        rows.append(['Memory Rank 0 Avg Power (mW)', self.parser.get_stat('system.mem_ctrls0_0.averagePower')])
        rows.append(['Memory Rank 1 Avg Power (mW)', self.parser.get_stat('system.mem_ctrls0_1.averagePower')])

        # Write CSV file
        try:
            with open(output_file, 'w', newline='', encoding='utf-8') as f:
                writer = csv.writer(f)
                writer.writerow(['Metric', 'Value'])
                writer.writerows(rows)

            print(f"CSV report generated successfully: {output_file}")
            return output_file

        except Exception as e:
            print(f"Error writing CSV file: {e}")
            sys.exit(1)


def main():
    """Main entry point"""

    if len(sys.argv) < 2:
        print("Usage: python3 generate_results_csv.py <stats_file> [output_csv]")
        print("\nExample:")
        print("  python3 generate_results_csv.py /home/siat/test/stats.txt results_20251105_143000.csv")
        sys.exit(1)

    stats_file = sys.argv[1]
    output_csv = sys.argv[2] if len(sys.argv) > 2 else None

    # Extract test name from path if possible
    test_name = 'unknown'
    if 'backprop' in stats_file.lower():
        test_name = 'backprop'
    elif 'kmeans' in stats_file.lower():
        test_name = 'kmeans'

    # Parse statistics
    print(f"Parsing statistics file: {stats_file}")
    parser = Gem5StatsParser(stats_file)
    parser.parse()
    print(f"Parsed {len(parser.stats)} statistics entries")

    # Generate CSV report
    generator = ResultsCSVGenerator(parser, test_name)
    output_file = generator.generate_csv(output_csv)

    print(f"\nResults summary:")
    print(f"  - Simulation time: {parser.get_stat('sim_seconds')} seconds")
    print(f"  - MVPP routing count: {parser.get_stat('system.ruby.network.ext_links00.int_node.mvpp_mgc_pso_routing_count', 'N/A')}")
    print(f"  - Average routing delay: {parser.get_stat('system.ruby.network.ext_links00.int_node.mvpp_mgc_pso_routing_delay::mean', 'N/A')} ticks")
    print(f"  - CSV output: {output_file}")


if __name__ == '__main__':
    main()
