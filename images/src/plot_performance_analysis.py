#!/usr/bin/env python3
"""
Comprehensive Performance Analysis of Mixed Workload
Generates a 3x2 subplot grid showing key performance metrics normalized to baseline
"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from color_config import COLORS, GRID_STYLE, LABELS, EDGE_COLOR, EDGE_WIDTH

# Configure matplotlib for better appearance (IEEE Transaction format)
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 11
plt.rcParams['axes.labelsize'] = 12
plt.rcParams['axes.titlesize'] = 13
plt.rcParams['xtick.labelsize'] = 10
plt.rcParams['ytick.labelsize'] = 11
plt.rcParams['legend.fontsize'] = 10

def plot_performance_analysis():
    """Generate comprehensive performance analysis with 3x2 subplots"""

    # Define paths
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_dir = os.path.dirname(script_dir)
    input_dir = os.path.join(project_dir, 'input')
    output_dir = os.path.join(project_dir, 'output')

    # Define subplot configuration (3 rows x 2 columns)
    subplot_config = [
        {
            'row': 0, 'col': 0,
            'file': 'execution_time_data.csv',
            'title': '(a) Execution Time',
            'ylabel': 'Normalized Execution Time',
            'lower_is_better': True
        },
        {
            'row': 0, 'col': 1,
            'file': 'latency_data.csv',
            'title': '(b) Network Latency',
            'ylabel': 'Normalized Network Latency',
            'lower_is_better': True
        },
        {
            'row': 1, 'col': 0,
            'file': 'hop_count_cpu_data.csv',
            'title': '(c) CPU Hop Count',
            'ylabel': 'Normalized Hop Count',
            'lower_is_better': True
        },
        {
            'row': 1, 'col': 1,
            'file': 'hop_count_gpu_data.csv',
            'title': '(d) GPU Hop Count',
            'ylabel': 'Normalized Hop Count',
            'lower_is_better': True
        },
        {
            'row': 2, 'col': 0,
            'file': 'energy_data.csv',
            'title': '(e) NoC Energy',
            'ylabel': 'Normalized NoC Energy',
            'lower_is_better': True
        },
        {
            'row': 2, 'col': 1,
            'file': 'energy_efficiency_data.csv',
            'title': '(f) Energy Efficiency',
            'ylabel': 'Normalized Energy Efficiency',
            'lower_is_better': False  # Higher is better
        }
    ]

    # Create figure with 3x2 subplots (IEEE Transaction full-width across two columns)
    fig, axes = plt.subplots(3, 2, figsize=(18, 14))
    fig.subplots_adjust(hspace=0.45, wspace=0.35)

    # Bar width and spacing (adjusted for IEEE Transaction format)
    bar_width = 0.22
    x_spacing_multiplier = 1.6

    # Plot each subplot
    for config in subplot_config:
        row, col = config['row'], config['col']
        ax = axes[row, col]

        # Read data
        data_file = os.path.join(input_dir, config['file'])
        df = pd.read_csv(data_file)

        # Determine column name for workload/application
        if 'hop_count' in config['file']:
            workload_col = 'application'
        else:
            workload_col = 'workload'

        # Extract data (handle both 'tb-tbp' and 'tb_tbp' column names)
        workloads = df[workload_col].values
        baseline = df['baseline'].values

        # Try different column name variants
        if 'tb-tbp' in df.columns:
            tb_tbp = df['tb-tbp'].values
        elif 'tb_tbp' in df.columns:
            tb_tbp = df['tb_tbp'].values
        else:
            raise KeyError(f"Cannot find tb-tbp or tb_tbp column in {config['file']}")

        proposed = df['proposed'].values

        # Create x positions with increased spacing
        x = np.arange(len(workloads)) * x_spacing_multiplier
        width = bar_width

        # Plot bars
        bars1 = ax.bar(x - width, baseline, width,
                      label=LABELS['baseline'],
                      color=COLORS['baseline'],
                      edgecolor=EDGE_COLOR,
                      linewidth=EDGE_WIDTH)

        bars2 = ax.bar(x, tb_tbp, width,
                      label=LABELS['tb_tbp'],
                      color=COLORS['tb_tbp'],
                      edgecolor=EDGE_COLOR,
                      linewidth=EDGE_WIDTH)

        bars3 = ax.bar(x + width, proposed, width,
                      label=LABELS['proposed'],
                      color=COLORS['proposed'],
                      edgecolor=EDGE_COLOR,
                      linewidth=EDGE_WIDTH)

        # Customize subplot
        ax.set_xlabel('Mixed Workload', fontsize=12, fontweight='bold')
        ax.set_ylabel(config['ylabel'], fontsize=12, fontweight='bold')
        ax.set_title(config['title'], fontsize=13, fontweight='bold', pad=10)
        ax.set_xticks(x)
        ax.set_xticklabels(workloads, rotation=0, ha='center', fontsize=8)

        # Set y-axis limits
        if config['lower_is_better']:
            ax.set_ylim(0, 1.2)
        else:  # Energy efficiency - higher is better
            ax.set_ylim(0, 1.5)

        # Add grid
        ax.grid(True, **GRID_STYLE, zorder=0)
        ax.set_axisbelow(True)

        # Don't add legend to individual subplots - will add shared legend later

        # Add average improvement text for "Average" bar
        if len(workloads) > 0 and workloads[-1] == 'Average':
            avg_idx = len(workloads) - 1
            if config['lower_is_better']:
                improvement_baseline = (1 - proposed[avg_idx]) * 100
                improvement_tbtbp = (1 - proposed[avg_idx]/tb_tbp[avg_idx]) * 100
            else:  # Energy efficiency
                improvement_baseline = (proposed[avg_idx] - 1) * 100
                improvement_tbtbp = (proposed[avg_idx]/tb_tbp[avg_idx] - 1) * 100

            print(f"{config['title']}: Proposed improvement = {improvement_baseline:.1f}% vs Baseline, {improvement_tbtbp:.1f}% vs TB-TBP")

    # Add shared legend at the bottom of the entire figure
    handles, labels = axes[0, 0].get_legend_handles_labels()
    fig.legend(handles, labels, loc='lower center', bbox_to_anchor=(0.5, -0.02),
               ncol=3, frameon=False, fontsize=11)

    # Adjust layout
    plt.tight_layout(pad=1.5)

    # Save figure
    output_file = os.path.join(output_dir, 'performance_analysis_mixed_workload.png')
    plt.savefig(output_file, dpi=300, bbox_inches='tight', pad_inches=0.1)
    print(f"\nFigure saved to: {output_file}")

    # Also save as PDF
    output_pdf = os.path.join(output_dir, 'performance_analysis_mixed_workload.pdf')
    plt.savefig(output_pdf, bbox_inches='tight', pad_inches=0.1)
    print(f"PDF saved to: {output_pdf}")

    plt.show()

    # Print summary statistics
    print("\n" + "="*70)
    print("PERFORMANCE ANALYSIS SUMMARY")
    print("="*70)

    for config in subplot_config:
        data_file = os.path.join(input_dir, config['file'])
        df = pd.read_csv(data_file)

        # Determine column name for workload/application
        if 'hop_count' in config['file']:
            workload_col = 'application'
        else:
            workload_col = 'workload'

        avg_row = df[df[workload_col] == 'Average']
        if not avg_row.empty:
            baseline_val = avg_row['baseline'].values[0]

            # Handle different column name formats
            if 'tb-tbp' in df.columns:
                tb_tbp_val = avg_row['tb-tbp'].values[0]
            else:
                tb_tbp_val = avg_row['tb_tbp'].values[0]

            proposed_val = avg_row['proposed'].values[0]

            print(f"\n{config['title']}:")
            print(f"  Average values: Baseline={baseline_val:.3f}, TB-TBP={tb_tbp_val:.3f}, Proposed={proposed_val:.3f}")

            if config['lower_is_better']:
                imp_baseline = (1 - proposed_val/baseline_val) * 100
                imp_tbtbp = (1 - proposed_val/tb_tbp_val) * 100
                print(f"  Proposed improvement: {imp_baseline:.1f}% vs Baseline, {imp_tbtbp:.1f}% vs TB-TBP")
            else:
                imp_baseline = (proposed_val/baseline_val - 1) * 100
                imp_tbtbp = (proposed_val/tb_tbp_val - 1) * 100
                print(f"  Proposed improvement: +{imp_baseline:.1f}% vs Baseline, +{imp_tbtbp:.1f}% vs TB-TBP")

    print("="*70)

if __name__ == '__main__':
    plot_performance_analysis()
