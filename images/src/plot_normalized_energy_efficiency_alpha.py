#!/usr/bin/env python3
"""
Normalized Energy Efficiency Analysis with ALPHA Router
Generates a grouped bar chart comparing ALPHA router design with other configurations
"""

import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for headless environments
import matplotlib.pyplot as plt
import numpy as np

# Configure matplotlib for better appearance
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 18
plt.rcParams['axes.labelsize'] = 22
plt.rcParams['axes.titlesize'] = 24
plt.rcParams['xtick.labelsize'] = 18
plt.rcParams['ytick.labelsize'] = 18
plt.rcParams['legend.fontsize'] = 16
plt.rcParams['figure.titlesize'] = 24

# Color scheme for 6 methods
COLORS_6 = {
    'Baseline': '#2C5F8D',   # Deep blue
    'VIX': '#E8A838',        # Golden yellow
    'DIP': '#48A14D',        # Green
    'O1TURN': '#C1666B',     # Coral red
    'OSCAR': '#9B59B6',      # Purple
    'Proposed': '#E74C3C',   # Bright red (ALPHA/Proposed)
}

EDGE_COLOR = '#2F2F2F'
EDGE_WIDTH = 0.7

def plot_normalized_energy_efficiency_alpha():
    """Generate normalized energy efficiency comparison bar chart"""

    # Define paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, 'input')
    output_dir = os.path.join(project_dir, 'output')

    # Read CSV data
    data_file = os.path.join(input_dir, 'normalized_energy_efficiency_alpha.csv')
    df = pd.read_csv(data_file)

    # Extract data
    benchmarks = df['Benchmark'].values
    baseline = df['Baseline'].values
    vix = df['VIX'].values
    dip = df['DIP'].values
    o1turn = df['O1TURN'].values
    oscar = df['OSCAR'].values
    proposed = df['Proposed'].values

    # Set up the bar chart
    x = np.arange(len(benchmarks)) * 1.8  # Label locations
    width = 0.24  # Width of bars

    fig, ax = plt.subplots(figsize=(24, 9))

    # Create bars
    bars1 = ax.bar(x - 2.5*width, baseline, width, label='Baseline',
                   color=COLORS_6['Baseline'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars2 = ax.bar(x - 1.5*width, vix, width, label='VIX',
                   color=COLORS_6['VIX'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars3 = ax.bar(x - 0.5*width, dip, width, label='DIP',
                   color=COLORS_6['DIP'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars4 = ax.bar(x + 0.5*width, o1turn, width, label='O1TURN',
                   color=COLORS_6['O1TURN'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars5 = ax.bar(x + 1.5*width, oscar, width, label='OSCAR',
                   color=COLORS_6['OSCAR'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars6 = ax.bar(x + 2.5*width, proposed, width, label='ALPHA (Proposed)',
                   color=COLORS_6['Proposed'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)

    # Customize the plot
    ax.set_xlabel('Benchmark Applications', fontweight='bold', fontsize=22)
    ax.set_ylabel('Normalized Energy Efficiency', fontweight='bold', fontsize=22)
    ax.set_xticks(x)
    ax.set_xticklabels(benchmarks, rotation=0, ha='center')
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.12), ncol=6, frameon=False)

    # Add grid for better readability
    ax.yaxis.grid(True, linestyle='--', alpha=0.25, color='#888888', linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)

    # Set y-axis limits
    ax.set_ylim(0, 1.3)

    # Adjust layout
    plt.tight_layout(pad=2.0)

    # Save figure
    output_file = os.path.join(output_dir, 'normalized_energy_efficiency_alpha.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.3)
    print(f"Figure saved to: {output_file}")

    # Also save as PDF
    output_pdf = os.path.join(output_dir, 'normalized_energy_efficiency_alpha.pdf')
    plt.savefig(output_pdf, bbox_inches='tight', pad_inches=0.3)
    print(f"PDF saved to: {output_pdf}")

    plt.close()

    # Print statistics
    print("\n" + "="*80)
    print("NORMALIZED ENERGY EFFICIENCY ANALYSIS (ALPHA Router)")
    print("="*80)
    print(f"{'Benchmark':<12} {'Baseline':<10} {'VIX':<10} {'DIP':<10} {'O1TURN':<10} {'OSCAR':<10} {'ALPHA':<10}")
    print("-"*80)
    for i, bm in enumerate(benchmarks):
        print(f"{bm:<12} {baseline[i]:<10.2f} {vix[i]:<10.2f} {dip[i]:<10.2f} {o1turn[i]:<10.2f} {oscar[i]:<10.2f} {proposed[i]:<10.2f}")
    print("="*80)

    # Calculate average improvement
    avg_proposed = np.mean(proposed)
    avg_baseline = np.mean(baseline)
    improvement = ((avg_proposed - avg_baseline) / avg_baseline) * 100
    print(f"\nAverage ALPHA Improvement over Baseline: {improvement:.1f}%")
    print("="*80)

if __name__ == '__main__':
    plot_normalized_energy_efficiency_alpha()
