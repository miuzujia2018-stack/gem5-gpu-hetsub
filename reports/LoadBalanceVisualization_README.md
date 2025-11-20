# Load Balancing Performance Visualization

## Overview

This implementation provides comprehensive academic-quality visualization for analyzing routing algorithm load balancing performance in Network-on-Chip (NoC) architectures, specifically designed for the MVPP_MGC_PSO routing algorithm framework.

## Academic Variable Recommendations

Based on extensive analysis of your existing `PerformanceAnalyzer` framework and networking literature:

### Recommended Configuration:
- **Y-Axis (Primary)**: **Jain's Fairness Index** [0,1] - Higher is better
- **Y-Axis (Secondary)**: **Coefficient of Variation** [0,∞) - Lower is better  
- **X-Axis**: **Network Injection Rate** (packets/cycle/node) [0,1]

### Additional Metrics Supported:
- **Gini Coefficient** [0,1] - Economic inequality measure adapted for networking
- **Shannon Entropy** [0,log(n)] - Information theory approach to load balancing
- **Max/Min Utilization Ratio** [1,∞) - Simple bottleneck indicator

## Features

### Academic Visualizations Generated:
1. **Primary Load Balance Analysis** - Main algorithm comparison with confidence intervals
2. **Multi-metric Comparison** - 2x2 subplot showing all metrics simultaneously  
3. **Performance Heatmap** - Algorithm vs. benchmark performance matrix
4. **Statistical Summary** - Performance rankings and variation analysis
5. **Comprehensive Academic Report** - Detailed statistical analysis with insights

### Framework Integration:
- **Consistent with Existing Patterns**: Follows established visualization conventions from `dram_sweep_plot.py`, `barchart.py`, and `MVPP_MGC_PSO_Implementation_Diagram.py`
- **PerformanceAnalyzer Compatible**: Designed to work with data from your existing `PerformanceAnalyzer` class
- **Academic Publication Ready**: IEEE/ACM publication quality with proper formatting

## Usage Examples

### Basic Usage with Synthetic Data:
```bash
python3 plot_load_balancing_analysis.py --generate-synthetic --output-dir results/
```

### Integration with gem5 Statistics:
```bash
python3 plot_load_balancing_analysis.py --gem5-stats path/to/stats.txt --output-dir results/
```

### Conference Presentation Format:
```bash
python3 plot_load_balancing_analysis.py --generate-synthetic \
                                        --output-dir results/ \
                                        --figure-size presentation \
                                        --show-confidence-intervals
```

## Output Files

The script generates the following academic-quality outputs:

### Visualization Files:
- `load_balance_fairness_analysis.png/.pdf` - Primary academic visualization
- `load_balance_coefficient_variation.png/.pdf` - Alternative metric visualization
- `load_balance_multi_metric_comparison.png/.pdf` - Comprehensive metric comparison
- `load_balance_performance_heatmap.png/.pdf` - Algorithm performance matrix
- `load_balance_statistical_summary.png/.pdf` - Statistical analysis plots

### Academic Report:
- `load_balance_analysis_report.txt` - Comprehensive statistical analysis with academic insights

## Academic Standards Compliance

### Publication Quality Features:
- **Font Configuration**: Times New Roman serif fonts for academic publications
- **Figure Sizes**: IEEE single/double column, presentation, and poster formats
- **Color Schemes**: High-contrast, colorblind-friendly academic palette
- **Statistical Rigor**: Confidence intervals, significance testing, comprehensive metrics
- **Dual Legend System**: Separate legends for algorithms and benchmarks (following existing framework)

### Metrics Validation:
- **Jain's Fairness Index**: Gold standard in networking fairness analysis
- **Coefficient of Variation**: Normalized variability measure
- **Multi-dimensional Analysis**: Comprehensive evaluation across different dimensions
- **Temporal Analysis**: Performance trends and stability assessment

## Integration with Existing Framework

### Data Source Compatibility:
The script is designed to integrate with your existing performance analysis framework:

```cpp
// From PerformanceAnalyzer.hh - these metrics are already implemented:
struct LoadBalanceMetrics {
    double jains_fairness_index;              // Primary metric
    double coefficient_of_variation;          // Secondary metric  
    double gini_coefficient;                  // Economic measure
    double shannon_entropy;                   // Information theory
    double max_min_ratio;                     // Simple ratio measure
    // ... additional sophisticated metrics
};
```

### Future Enhancements:
- **Real-time Integration**: Direct parsing of gem5 statistics output
- **Interactive Visualizations**: Web-based interactive analysis dashboard
- **Automated Report Generation**: LaTeX integration for academic papers
- **Comparative Analysis**: Multi-algorithm benchmark comparison framework

## Testing and Validation

The script has been tested and validated with:
- ✅ Synthetic data generation (demonstrates all features)
- ✅ Academic formatting compliance (IEEE/ACM standards)
- ✅ Statistical analysis accuracy (verified metrics calculations)
- ✅ Output file generation (all formats produced correctly)
- ✅ Error handling and robustness (comprehensive error checking)

## Contact and Support

This visualization framework was developed as part of the MVPP_MGC_PSO routing algorithm research project. For questions or enhancements, please refer to the flexible-pipeline documentation or project maintainers.