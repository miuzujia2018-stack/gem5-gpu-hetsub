# CSV to Python Script Mapping Documentation

## Overview
This document provides a complete mapping between CSV data files in the `input/` directory and their corresponding Python plotting scripts in the `src/` directory.

## Complete Mapping Table

| CSV File | Python Script | Description | Output Files |
|----------|--------------|-------------|--------------|
| `dynamic_energy_data.csv` | `plot_dynamic_energy.py` | Dynamic energy consumption analysis | `dynamic_energy.png`, `dynamic_energy.pdf` |
| `energy_data.csv` | `plot_energy_analysis.py` | Overall energy analysis | `energy_analysis.png`, `energy_analysis.pdf` |
| `energy_efficiency_data.csv` | `plot_energy_efficiency.py` | Energy efficiency comparison | `energy_efficiency.png`, `energy_efficiency.pdf` |
| `execution_time_data.csv` | `plot_execution_time.py` | Execution time comparison | `execution_time.png`, `execution_time.pdf` |
| `hop_count_cpu_applications.csv` | `plot_hop_count_cpu_applications.py` | CPU application hop count analysis | `hop_count_cpu_applications_comparison.png/pdf` |
| `hop_count_cpu_data.csv` | `plot_hop_count_cpu.py` | CPU hop count normalized data | `hop_count_cpu_applications.png/pdf` |
| `hop_count_gpu_data.csv` | `plot_hop_count_gpu.py` | **GPU hop count normalized data** ✨NEW | `hop_count_gpu_applications.png/pdf` |
| `hop_count_queuing_latency_gpu_applications.csv` | `plot_hop_count_queuing_latency_gpu.py` | GPU queuing latency and hop count | `hop_count_queuing_latency_gpu_applications.png/pdf` |
| `latency_data.csv` | `plot_latency_analysis.py` | Network latency analysis | `latency_analysis.png/pdf` |
| `normalized_energy_efficiency_alpha.csv` | `plot_normalized_energy_efficiency_alpha.py` | ALPHA router energy efficiency | `normalized_energy_efficiency_alpha.png/pdf` |
| `normalized_network_latency.csv` | `plot_normalized_network_latency.py` | Normalized network latency | `normalized_network_latency.png/pdf` |
| `normalized_throughput.csv` | `plot_normalized_throughput.py` | Normalized throughput comparison | `normalized_throughput.png/pdf` |
| `static_energy_data.csv` | `plot_static_energy.py` | Static energy consumption | `static_energy.png/pdf` |
| `synthetic_traffic_data.csv` | `plot_synthetic_traffic.py` | Synthetic traffic pattern analysis | `synthetic_traffic.png/pdf` |

### Special Scripts

| Script | Purpose | Input CSVs |
|--------|---------|-----------|
| `plot_performance_analysis.py` | Comprehensive 3×2 subplot analysis | Multiple CSVs (execution_time, latency, hop_count, energy, etc.) |
| `color_config.py` | Shared color scheme configuration | N/A (config only) |
| `generate_all_plots.sh` | Batch generation script | All plot_*.py scripts |

**Total CSV Files**: 14  
**Total Individual Plot Scripts**: 14  
**Total Scripts (including utilities)**: 17  
**Mapping Status**: ✓ Complete (100%)

## Recently Added Scripts

### `plot_hop_count_gpu.py` ✨ NEW (Created 2026-01-06)
- **Purpose**: Generates hop count analysis visualizations for GPU applications
- **Input**: `input/hop_count_gpu_data.csv`
- **Output**:
  - `output/hop_count_gpu_applications.png` (300 DPI)
  - `output/hop_count_gpu_applications.pdf` (Publication quality)
- **Features**:
  - Grouped bar chart comparing Baseline, TB-TBP, and Proposed routing methods
  - Academic color scheme (blue, coral, green)
  - Professional grid styling and typography
  - Statistical summary including improvement percentages
- **Performance Metrics**:
  - Proposed vs Baseline: 12.7% reduction in hop count
  - Proposed vs TB-TBP: 17.1% reduction in hop count

## Script Design Principles

All plotting scripts follow these consistent design patterns:

### 1. File Structure Template
```python
#!/usr/bin/env python3
"""Docstring describing the script purpose"""

import os
import pandas as pd
import matplotlib.pyplot as plt
import numpy as np
from color_config import COLORS, EDGE_COLOR, EDGE_WIDTH, GRID_STYLE, LEGEND_STYLE, LABELS

# Matplotlib configuration
plt.rcParams['font.family'] = 'serif'
plt.rcParams['font.size'] = 18
# ... more config

def plot_function():
    # 1. Path setup
    # 2. Data loading from CSV
    # 3. Data extraction
    # 4. Plot creation
    # 5. Customization
    # 6. Saving (PNG + PDF)
    # 7. Statistics printing

if __name__ == '__main__':
    plot_function()
```

### 2. Shared Color Scheme
Defined in `src/color_config.py`:
- **Baseline**: Deep professional blue `#2C5F8D`
- **TB-TBP**: Muted coral red `#C1666B`
- **Proposed**: Professional green `#48A14D`
- **Edge Color**: Dark gray `#2F2F2F`

### 3. Output Formats
All scripts generate dual outputs:
- **PNG**: 300 DPI raster image for presentations
- **PDF**: Vector format for publication-quality documents

### 4. Typography Standards
- Font family: Serif (academic standard)
- Base font size: 18pt
- Axis labels: 22pt (bold)
- Tick labels: 18pt
- Legend: 16-18pt

### 5. Statistical Analysis
Each script prints:
- Raw data table
- Average values per category
- Improvement percentages
- Comparative metrics

## Usage

### Run Individual Script
```bash
cd /home/siat/gem5-gpu-bak/images/src/
python3 plot_hop_count_gpu.py
```

### Generate All Plots
```bash
cd /home/siat/gem5-gpu-bak/images/src/
./generate_all_plots.sh
```

### Generate Specific Plot Type
```bash
cd /home/siat/gem5-gpu-bak/images/src/
python3 plot_hop_count_cpu.py          # CPU hop count only
python3 plot_hop_count_gpu.py          # GPU hop count only
python3 plot_performance_analysis.py   # Comprehensive analysis
```

## Directory Structure

```
/home/siat/gem5-gpu-bak/images/
├── input/                  # CSV data files (14 files)
│   ├── dynamic_energy_data.csv
│   ├── hop_count_gpu_data.csv          ← Corresponds to plot_hop_count_gpu.py
│   ├── normalized_throughput.csv
│   └── ...
├── src/                    # Python plotting scripts (17 files)
│   ├── color_config.py                 ← Shared color configuration
│   ├── generate_all_plots.sh           ← Batch generation script ✨NEW
│   ├── plot_hop_count_gpu.py           ← GPU hop count plotting ✨NEW
│   ├── plot_performance_analysis.py    ← Multi-CSV comprehensive analysis
│   └── ... (14 individual plot scripts)
└── output/                 # Generated figures (28+ files)
    ├── hop_count_gpu_applications.png  ✨NEW
    ├── hop_count_gpu_applications.pdf  ✨NEW
    └── ... (14 PNG + 14 PDF files minimum)
```

## Quality Assurance

### Verification Checklist
- ✓ All 14 CSV files have corresponding Python scripts
- ✓ All scripts follow consistent coding style
- ✓ All scripts import from shared `color_config.py`
- ✓ All scripts generate both PNG and PDF outputs
- ✓ All scripts include statistical summaries
- ✓ All scripts use academic-quality formatting
- ✓ All scripts are executable (`chmod +x`)
- ✓ Batch generation script created (`generate_all_plots.sh`)

### Testing Status
- ✓ `plot_hop_count_gpu.py` successfully tested and verified
- ✓ Output files created in correct directory with proper naming
- ✓ Statistical summary displays correctly with improvement metrics
- ✓ Figure dimensions (16×9) and DPI (300) meet publication standards
- ✓ Both PNG and PDF formats generated successfully

## Implementation Summary

### Problem Statement
The `input/` directory contained 14 CSV files, but only 13 had corresponding Python plotting scripts. The `hop_count_gpu_data.csv` file lacked a dedicated visualization script.

### Solution Implemented
Created `plot_hop_count_gpu.py` following the established project patterns:
1. **Template Adherence**: Used `plot_hop_count_cpu.py` as reference template
2. **Color Consistency**: Imported shared colors from `color_config.py`
3. **Dual Output**: Generates both PNG (300 DPI) and PDF formats
4. **Statistical Analysis**: Includes comprehensive improvement metrics
5. **Academic Formatting**: Serif fonts, proper spacing, grid styling

### Additional Enhancements
1. **Batch Script**: Created `generate_all_plots.sh` for one-command generation of all plots
2. **Documentation**: Created this comprehensive mapping document
3. **Verification**: Tested script execution and output generation

## Maintenance Guidelines

### Adding New CSV Files
1. Create CSV file in `input/` directory with proper column headers
2. Create corresponding `plot_*.py` script in `src/` directory
3. Follow existing script templates for consistency
4. Import colors from `color_config.py` (do not hardcode colors)
5. Add script to `generate_all_plots.sh` scripts array
6. Update this mapping document with new entry
7. Test script individually: `python3 plot_new_script.py`
8. Test batch generation: `./generate_all_plots.sh`

### Modifying Existing Scripts
1. **Preserve Interfaces**: Keep function names and file paths unchanged
2. **Maintain Config**: Use consistent matplotlib configuration
3. **Dual Output**: Always generate both PNG and PDF
4. **Update Stats**: Modify statistical analysis if data structure changes
5. **Test Thoroughly**: Regenerate all plots after modifications
6. **Document Changes**: Update this file with modification notes

### Color Scheme Updates
To change the color scheme globally:
1. Edit `src/color_config.py` only
2. Do NOT modify individual plot scripts
3. Regenerate all plots: `./generate_all_plots.sh`
4. Verify visual consistency across all outputs

## Performance Metrics (Example: GPU Hop Count)

```
============================================================
HOP COUNT ANALYSIS SUMMARY (GPU Applications)
============================================================
Application     Baseline     TB-TBP       Proposed    
------------------------------------------------------------
BFS             1.00         1.05         0.87        
BT              1.00         1.07         0.85        
CA              1.00         1.04         0.89        
GA              1.00         1.06         0.86        
HW              1.00         1.04         0.89        
KM              1.00         1.07         0.85        
NW              1.00         1.04         0.90        
Average         1.00         1.05         0.87        
============================================================

Average Improvement:
  Proposed vs Baseline: 12.7% reduction
  Proposed vs TB-TBP:   17.1% reduction
============================================================
```

## References

### Key Files
- **Color Configuration**: `src/color_config.py` - Centralized color scheme
- **Template Script**: `src/plot_hop_count_cpu.py` - Reference implementation
- **Batch Generator**: `src/generate_all_plots.sh` - Mass plot generation
- **Comprehensive Analysis**: `src/plot_performance_analysis.py` - Multi-metric visualization

### Documentation
- **Project Instructions**: `/home/siat/gem5-gpu-bak/CLAUDE.md`
- **CSV Data Structure**: See individual CSV headers in `input/` directory
- **This Document**: `/home/siat/gem5-gpu-bak/images/CSV_PYTHON_MAPPING.md`

---

**Document Version**: 1.1  
**Last Updated**: 2026-01-06 15:35 UTC+8  
**Status**: ✓ Complete - All CSV files mapped to Python scripts  
**New Files**: `plot_hop_count_gpu.py`, `generate_all_plots.sh`, `CSV_PYTHON_MAPPING.md`
