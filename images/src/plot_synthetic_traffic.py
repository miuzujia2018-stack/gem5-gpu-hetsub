#!/usr/bin/env python3
"""
Synthetic Traffic Analysis Visualization
Generates a 3x3 subplot grid showing network latency, throughput, and link utilization
across three traffic patterns (bit-reverse, transpose, uniform-random)
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from color_config import COLORS, GRID_STYLE, LABELS

# Configure matplotlib for better appearance (IEEE Transaction format)
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 10
plt.rcParams['axes.labelsize'] = 11
plt.rcParams['axes.titlesize'] = 12
plt.rcParams['xtick.labelsize'] = 9
plt.rcParams['ytick.labelsize'] = 10
plt.rcParams['legend.fontsize'] = 9

# Marker styles for each method
MARKERS = {
    'baseline': 'o',      # Circle
    'tb_tbp': 's',        # Square
    'proposed': '^',      # Triangle (as requested)
}

# Line styles (adjusted for IEEE Transaction format)
LINE_WIDTH = 2.0
MARKER_SIZE = 7

def plot_synthetic_traffic():
    """Generate synthetic traffic analysis with 3x3 subplots"""

    # Define paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, 'input')
    output_dir = os.path.join(project_dir, 'output')

    # Read CSV data
    data_file = os.path.join(input_dir, 'synthetic_traffic_data.csv')
    df = pd.read_csv(data_file)

    # Define traffic patterns and metrics
    traffic_patterns = ['bit_reverse', 'transpose', 'uniform_random']
    traffic_labels = ['(a) Bit-Reverse', '(b) Transpose', '(c) Uniform-Random']
    metrics = ['latency', 'throughput', 'link_util']
    metric_labels = {
        'latency': 'Network Latency (Cycles)',
        'throughput': 'Throughput (Packets/Cycle/Node)',
        'link_util': 'Link Utilization (%)'
    }

    # Create figure with 3x3 subplots (IEEE Transaction full-width across two columns)
    fig, axes = plt.subplots(3, 3, figsize=(13, 11))
    fig.subplots_adjust(hspace=0.35, wspace=0.28)

    # Plot each subplot
    for row, metric in enumerate(metrics):
        for col, (pattern, pattern_label) in enumerate(zip(traffic_patterns, traffic_labels)):
            ax = axes[row, col]

            # Filter data for this traffic pattern and metric
            data = df[(df['traffic_pattern'] == pattern) & (df['metric'] == metric)]

            injection_rate = data['injection_rate'].values
            baseline = data['baseline'].values
            tb_tbp = data['tb_tbp'].values
            proposed = data['proposed'].values

            # Plot lines with markers
            ax.plot(injection_rate, baseline,
                   marker=MARKERS['baseline'],
                   color=COLORS['baseline'],
                   linewidth=LINE_WIDTH,
                   markersize=MARKER_SIZE,
                   label=LABELS['baseline'],
                   markeredgewidth=1.0,
                   markeredgecolor='white')

            ax.plot(injection_rate, tb_tbp,
                   marker=MARKERS['tb_tbp'],
                   color=COLORS['tb_tbp'],
                   linewidth=LINE_WIDTH,
                   markersize=MARKER_SIZE,
                   label=LABELS['tb_tbp'],
                   markeredgewidth=1.0,
                   markeredgecolor='white')

            ax.plot(injection_rate, proposed,
                   marker=MARKERS['proposed'],
                   color=COLORS['proposed'],
                   linewidth=LINE_WIDTH,
                   markersize=MARKER_SIZE,
                   label=LABELS['proposed'],
                   markeredgewidth=1.0,
                   markeredgecolor='white')

            # Customize subplot
            ax.set_xlabel('Injection Rate (Packets/Cycle/Node)', fontsize=11, fontweight='bold')
            ax.set_ylabel(metric_labels[metric], fontsize=11, fontweight='bold')

            # Add title for top row only
            if row == 0:
                ax.set_title(pattern_label, fontsize=12, fontweight='bold', pad=10)

            # Add grid
            ax.grid(True, **GRID_STYLE, zorder=0)
            ax.set_axisbelow(True)

            # Set x-axis limits
            ax.set_xlim(0.0, 0.16)

            # Don't add legend to individual subplots - will add shared legend later

            # Format y-axis based on metric
            if metric == 'throughput':
                ax.set_ylim(0, 0.15)
            elif metric == 'link_util':
                ax.set_ylim(0, 110)
            else:  # latency
                ax.set_ylim(0, None)

    # Add shared legend at the bottom of the entire figure
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc='lower center', bbox_to_anchor=(0.5, -0.02),
               ncol=3, frameon=False, fontsize=10)

    # Adjust layout
    plt.tight_layout(pad=1.0)

    # Save figure
    output_file = os.path.join(output_dir, 'synthetic_traffic_analysis.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.05)
    print(f"Figure saved to: {output_file}")

    # Also save as PDF
    output_pdf = os.path.join(output_dir, 'synthetic_traffic_analysis.pdf')
    plt.savefig(output_pdf, bbox_inches='tight', pad_inches=0.05)
    print(f"PDF saved to: {output_pdf}")

    plt.show()

    # Print summary statistics
    print("\n" + "="*70)
    print("SYNTHETIC TRAFFIC ANALYSIS SUMMARY")
    print("="*70)

    for pattern, pattern_label in zip(traffic_patterns, traffic_labels):
        print(f"\n{pattern_label}:")
        print("-"*70)

        for metric in metrics:
            data = df[(df['traffic_pattern'] == pattern) & (df['metric'] == metric)]

            # Get peak values (at max injection rate)
            max_idx = data['injection_rate'].idxmax()
            baseline_peak = data.loc[max_idx, 'baseline']
            tb_tbp_peak = data.loc[max_idx, 'tb_tbp']
            proposed_peak = data.loc[max_idx, 'proposed']

            print(f"  {metric_labels[metric]}:")
            print(f"    Peak values @ 0.15 injection rate:")
            print(f"      Baseline: {baseline_peak:.3f}, TB-TBP: {tb_tbp_peak:.3f}, Proposed: {proposed_peak:.3f}")

            if metric == 'latency':
                improvement_baseline = (1 - proposed_peak/baseline_peak) * 100
                improvement_tbtbp = (1 - proposed_peak/tb_tbp_peak) * 100
                print(f"    Proposed improvement: {improvement_baseline:.1f}% vs Baseline, {improvement_tbtbp:.1f}% vs TB-TBP")
            elif metric == 'throughput' or metric == 'link_util':
                improvement_baseline = (proposed_peak/baseline_peak - 1) * 100
                improvement_tbtbp = (proposed_peak/tb_tbp_peak - 1) * 100
                print(f"    Proposed improvement: +{improvement_baseline:.1f}% vs Baseline, +{improvement_tbtbp:.1f}% vs TB-TBP")

    print("="*70)

if __name__ == '__main__':
    plot_synthetic_traffic()
