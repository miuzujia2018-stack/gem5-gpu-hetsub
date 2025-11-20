#!/usr/bin/env python3
"""
Execution Time Analysis Visualization for Mixed Workload
Generates a grouped bar chart showing normalized execution time for different routing methods
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from color_config import COLORS, EDGE_COLOR, EDGE_WIDTH, GRID_STYLE, LEGEND_STYLE, LABELS

# Configure matplotlib for better appearance
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 18
plt.rcParams['axes.labelsize'] = 22
plt.rcParams['axes.titlesize'] = 24
plt.rcParams['xtick.labelsize'] = 18
plt.rcParams['ytick.labelsize'] = 18
plt.rcParams['legend.fontsize'] = 18
plt.rcParams['figure.titlesize'] = 24

def plot_execution_time():
    """Generate execution time analysis bar chart from CSV data"""

    # Define paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, 'input')
    output_dir = os.path.join(project_dir, 'output')

    # Read CSV data
    data_file = os.path.join(input_dir, 'execution_time_data.csv')
    df = pd.read_csv(data_file)

    # Extract data
    workloads = df['workload'].values
    baseline = df['baseline'].values
    tb_tbp = df['tb-tbp'].values
    proposed = df['proposed'].values

    # Set up the bar chart
    x = np.arange(len(workloads)) * 1.3  # Label locations with increased spacing
    width = 0.22  # Width of bars (narrower for better spacing)

    fig, ax = plt.subplots(figsize=(18, 9))

    # Create bars with different colors
    bars1 = ax.bar(x - width, baseline, width, label=LABELS['baseline'],
                   color=COLORS['baseline'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars2 = ax.bar(x, tb_tbp, width, label=LABELS['tb_tbp'],
                   color=COLORS['tb_tbp'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)
    bars3 = ax.bar(x + width, proposed, width, label=LABELS['proposed'],
                   color=COLORS['proposed'], edgecolor=EDGE_COLOR, linewidth=EDGE_WIDTH)

    # Customize the plot
    ax.set_xlabel('Mixed Workload', fontweight='bold', fontsize=22)
    ax.set_ylabel('Execution Time (Normalized)', fontweight='bold', fontsize=22)
    ax.set_xticks(x)
    ax.set_xticklabels(workloads, rotation=0, ha='center')
    ax.legend(loc='upper center', bbox_to_anchor=(0.5, 1.15), ncol=3, **LEGEND_STYLE)

    # Add grid for better readability
    ax.yaxis.grid(True, **GRID_STYLE, zorder=0)
    ax.set_axisbelow(True)

    # Set y-axis limits
    ax.set_ylim(0, 1.2)

    # Adjust layout to prevent label cutoff
    plt.tight_layout(pad=2.0)

    # Save figure
    output_file = os.path.join(output_dir, 'execution_time_mixed_workload.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.3)
    print(f"Figure saved to: {output_file}")

    # Also save as PDF for publication quality
    output_pdf = os.path.join(output_dir, 'execution_time_mixed_workload.pdf')
    plt.savefig(output_pdf, bbox_inches='tight', pad_inches=0.3)
    print(f"PDF saved to: {output_pdf}")

    plt.show()

    # Print statistics summary
    print("\n" + "="*60)
    print("EXECUTION TIME ANALYSIS SUMMARY")
    print("="*60)
    print(f"{'Workload':<20} {'Baseline':<12} {'TB-TBP':<12} {'Proposed':<12}")
    print("-"*60)
    for i, wl in enumerate(workloads):
        print(f"{wl:<20} {baseline[i]:<12.2f} {tb_tbp[i]:<12.2f} {proposed[i]:<12.2f}")
    print("="*60)

    # Calculate improvement percentages
    avg_improvement_baseline = (1 - proposed[-1]) * 100
    avg_improvement_tbtbp = ((tb_tbp[-1] - proposed[-1]) / tb_tbp[-1]) * 100

    print(f"\nAverage Improvement:")
    print(f"  Proposed vs Baseline: {avg_improvement_baseline:.1f}% reduction")
    print(f"  Proposed vs TB-TBP:   {avg_improvement_tbtbp:.1f}% reduction")
    print("="*60)

if __name__ == '__main__':
    plot_execution_time()
