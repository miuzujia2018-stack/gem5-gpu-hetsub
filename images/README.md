# Visualization System for MVPP_MGC_PSO Performance Analysis

This directory contains Python scripts for generating performance analysis figures for the MVPP_MGC_PSO routing algorithm.

## Directory Structure

```
images/
├── src/              # Python plotting scripts
│   ├── plot_latency_analysis.py
│   └── plot_hop_count_cpu.py
├── input/            # CSV data files
│   ├── latency_data.csv
│   └── hop_count_cpu_data.csv
├── output/           # Generated figures (PNG and PDF)
│   ├── latency_analysis_mixed_workload.png
│   ├── latency_analysis_mixed_workload.pdf
│   ├── hop_count_cpu_applications.png
│   └── hop_count_cpu_applications.pdf
└── README.md         # This file
```

## Current Figures

### 1. Latency Analysis of Mixed Workload

**File**: `src/plot_latency_analysis.py`
**Data**: `input/latency_data.csv`
**Output**: `output/latency_analysis_mixed_workload.{png,pdf}`

**Description**:
- Compares normalized packet latency across three routing methods (Baseline, TB-TBP, Proposed)
- Evaluates performance on 8 mixed workloads
- Demonstrates that the Proposed method achieves the lowest latency overall

**Key Results**:
- Average latency reduction: 21.4% vs Baseline, 14.8% vs TB-TBP
- Consistent improvement across all workload combinations

### 2. Hop Count Analysis of CPU Applications

**File**: `src/plot_hop_count_cpu.py`
**Data**: `input/hop_count_cpu_data.csv`
**Output**: `output/hop_count_cpu_applications.{png,pdf}`

**Description**:
- Compares normalized hop count for CPU applications across three routing methods (Baseline, TB-TBP, Proposed)
- Evaluates performance on 6 CPU applications plus average
- Demonstrates that the Proposed method achieves the lowest hop count overall

**Key Results**:
- Average hop count reduction: 23.3% vs Baseline, 15.1% vs TB-TBP
- Consistent improvement across all CPU applications

## Usage

### Running the Scripts

**Latency Analysis:**
```bash
cd /home/siat/gem5-gpu-bak/images
python3 src/plot_latency_analysis.py
```

**Hop Count Analysis (CPU):**
```bash
cd /home/siat/gem5-gpu-bak/images
python3 src/plot_hop_count_cpu.py
```

Or run from any directory:
```bash
python3 /home/siat/gem5-gpu-bak/images/src/plot_latency_analysis.py
python3 /home/siat/gem5-gpu-bak/images/src/plot_hop_count_cpu.py
```

### Updating Data

To update the visualizations with your own simulation results:

**1. Latency Data:**
- Edit the CSV file: `input/latency_data.csv`
- Format:
  ```csv
  workload,baseline,tb-tbp,proposed
  BS_SW_GA,1.0,0.934,0.792
  X264_FR_BFS,1.0,0.896,0.763
  ...
  ```

**2. Hop Count Data (CPU):**
- Edit the CSV file: `input/hop_count_cpu_data.csv`
- Format:
  ```csv
  application,baseline,tb-tbp,proposed
  BS,1.0,0.887,0.753
  BT,1.0,0.921,0.794
  ...
  ```

**3. Run the plotting script again**

## Requirements

- Python 3.x
- Required packages:
  - pandas
  - matplotlib
  - numpy

Install dependencies:
```bash
pip3 install pandas matplotlib numpy
```

## Output Formats

Each script generates two output formats:
- **PNG**: High-resolution (300 DPI) for presentations and reports
- **PDF**: Vector format for publication-quality figures

## Workload Descriptions

### Mixed Workload Combinations

The mixed workload combinations consist of:

| Workload Code | Components |
|---------------|------------|
| BS_SW_GA | Backprop + Streamcluster + Gaussian |
| X264_FR_BFS | X264 + Ferret + BFS |
| BT_CA_NW | BTree + Canneal + NW |
| FL_BS_KM | Fluidanimate + Blackscholes + Kmeans |
| SW_BT_BP | Streamcluster + BTree + Backprop |
| X264_CA_HW | X264 + Canneal + Hotspot |
| FL_FR_HS | Fluidanimate + Ferret + Hotspot |
| Average | Overall average performance |

### CPU Applications

The CPU applications evaluated for hop count analysis:

| Application | Full Name | Description |
|-------------|-----------|-------------|
| BS | Backprop | Backpropagation neural network training |
| BT | BTree | Binary tree operations |
| FR | Ferret | Image similarity search |
| SW | Streamcluster | Stream clustering algorithm |
| X264 | X264 | Video encoding application |
| FL | Fluidanimate | Fluid dynamics simulation |
| Average | Overall average | Average performance across all applications |

## Adding New Figures

To add a new visualization:

1. Create CSV data file in `input/` directory
2. Create Python script in `src/` directory
3. Follow the naming convention: `plot_<metric>_<description>.py`
4. Save outputs to `output/` directory
5. Update this README with figure description

## Notes

- All values are normalized to the baseline method
- Sample data is provided for demonstration purposes
- Replace with actual simulation results for accurate analysis
- Scripts use matplotlib's 'Agg' backend for non-interactive plotting
- All figures feature large fonts and clean layouts suitable for academic publications
- Legend is positioned above plots to avoid overlapping with data bars
