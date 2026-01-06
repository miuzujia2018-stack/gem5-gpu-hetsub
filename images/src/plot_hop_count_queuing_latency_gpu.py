#!/usr/bin/env python3
"""
Hop Count and Queuing Latency Analysis for GPU Applications
Generates a grouped bar chart showing both hop count and queuing latency metrics
Lower values indicate better performance
"""

import os
import pandas as pd
import matplotlib
matplotlib.use('Agg')  # Non-interactive backend for headless environments
import matplotlib.pyplot as plt
import numpy as np

# Configure matplotlib for better appearance
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 16
plt.rcParams['axes.labelsize'] = 20
plt.rcParams['axes.titlesize'] = 22
plt.rcParams['xtick.labelsize'] = 16
plt.rcParams['ytick.labelsize'] = 16
plt.rcParams['legend.fontsize'] = 14
plt.rcParams['figure.titlesize'] = 22

# Color scheme for 7 methods
COLORS_7 = {
    'Baseline': '#2C5F8D',        # Deep blue
    'OSCAR': '#E8A838',           # Golden yellow
    'Shortcut': '#48A14D',        # Green
    'FTBY': '#C1666B',            # Coral red
    'FTBY_PG': '#9B59B6',         # Purple
    'Adapt-NoC-noRL': '#1ABC9C',  # Turquoise
    'Adapt-NoC': '#E74C3C',       # Bright red
}

EDGE_COLOR = '#2F2F2F'
EDGE_WIDTH = 0.7

def plot_hop_count_queuing_latency_gpu():
    """Generate hop count and queuing latency analysis for GPU applications"""

    # Define paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, 'input')
    output_dir = os.path.join(project_dir, 'output')

    # Read CSV data
    data_file = os.path.join(input_dir, 'hop_count_queuing_latency_gpu_applications.csv')
    df = pd.read_csv(data_file)

    # Separate hop count and queuing latency data
    hop_df = df[df['Metric'] == 'Hop_Count']

    # Extract data
    applications = hop_df['Application'].values
    baseline = hop_df['Baseline'].values
    oscar = hop_df['OSCAR'].values
    shortcut = hop_df['Shortcut'].values
    ftby = hop_df['FTBY'].values
    ftby_pg = hop_df['FTBY_PG'].values
    adapt_noc_norl = hop_df['Adapt-NoC-noRL'].values
    adapt_noc = hop_df['Adapt-NoC'].values

    # Set up the bar chart
    x = np.arange(len(applications)) * 2.2
    width = 0.27

    fig, ax = plt.subplots(figsize=(24, 9))

    # Create bars
    bars1 = ax.bar(x - 3*width, baseline, width, label='Baseline',
                   color=COLORS_7['Baseline'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars2 = ax.bar(x - 2*width, oscar, width, label='OSCAR',
                   color=COLORS_7['OSCAR'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars3 = ax.bar(x - width, shortcut, width, label='Shortcut',
                   color=COLORS_7['Shortcut'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars4 = ax.bar(x, ftby, width, label='FTBY',
                   color=COLORS_7['FTBY'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars5 = ax.bar(x + width, ftby_pg, width, label='FTBY_PG',
                   color=COLORS_7['FTBY_PG'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars6 = ax.bar(x + 2*width, adapt_noc_norl, width, label='Adapt-NoC-noRL',
                   color=COLORS_7['Adapt-NoC-noRL'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars7 = ax.bar(x + 3*width, adapt_noc, width, label='Adapt-NoC',
                   color=COLORS_7['Adapt-NoC'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)

    # Customize the plot
    ax.set_xlabel('GPU Applications', fontweight='bold', fontsize=20)
    ax.set_ylabel('Hop Count and Queuing Latency (Normalized)', fontweight='bold', fontsize=20)
    ax.set_xticks(x)
    ax.set_xticklabels(applications, rotation=0, ha='center')
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.12), ncol=7, frameon=False)

    # Add grid
    ax.yaxis.grid(True, linestyle='--', alpha=0.25, color='#888888', linewidth=0.8, zorder=0)
    ax.set_axisbelow(True)

    # Set y-axis limits
    ax.set_ylim(0, 1.1)

    # Adjust layout
    plt.tight_layout(pad=2.0)

    # Save figure
    output_file = os.path.join(output_dir, 'hop_count_queuing_latency_gpu_applications.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.3)
    print(f"Figure saved to: {output_file}")

    output_pdf = os.path.join(output_dir, 'hop_count_queuing_latency_gpu_applications.pdf')
    plt.savefig(output_pdf, bbox_inches='tight', pad_inches=0.3)
    print(f"PDF saved to: {output_pdf}")

    plt.close()

    # Print statistics
    print("\n" + "="*100)
    print("HOP COUNT AND QUEUING LATENCY ANALYSIS - GPU APPLICATIONS")
    print("="*100)
    print(f"{'App':<15} {'Baseline':<10} {'OSCAR':<10} {'Shortcut':<10} {'FTBY':<10} {'FTBY_PG':<10} {'NoC-noRL':<10} {'Adapt-NoC':<10}")
    print("-"*100)
    for i, app in enumerate(applications):
        print(f"{app:<15} {baseline[i]:<10.2f} {oscar[i]:<10.2f} {shortcut[i]:<10.2f} {ftby[i]:<10.2f} {ftby_pg[i]:<10.2f} {adapt_noc_norl[i]:<10.2f} {adapt_noc[i]:<10.2f}")
    print("="*100)

    # Calculate improvements for average rows
    avg_indices = [i for i, app in enumerate(applications) if 'Average' in app]
    if avg_indices:
        for idx in avg_indices:
            app_name = applications[idx]
            best_value = min(shortcut[idx], adapt_noc_norl[idx])
            reduction = ((baseline[idx] - best_value) / baseline[idx]) * 100
            print(f"\n{app_name}: Best reduction vs Baseline: {reduction:.1f}%")
    print("="*100)

if __name__ == '__main__':
    plot_hop_count_queuing_latency_gpu()
