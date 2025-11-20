"""
Academic Color Scheme Configuration
Shared color palette for all visualization scripts
Based on professional academic publication standards
"""

# Academic color scheme - designed for clarity in both print and digital media
# Colors are colorblind-friendly and professional
COLORS = {
    'baseline': '#2C5F8D',      # Deep professional blue
    'tb_tbp': '#C1666B',        # Muted coral red
    'proposed': '#48A14D',      # Professional green
}

# Alternative academic color schemes (commented out, can be swapped)
# Scheme 2 - Nature/Science style
# COLORS = {
#     'baseline': '#3E5F8A',
#     'tb_tbp': '#C4654F',
#     'proposed': '#5E9152',
# }

# Scheme 3 - Elegant grayscale-friendly
# COLORS = {
#     'baseline': '#4E6C8B',
#     'tb_tbp': '#B65D5D',
#     'proposed': '#5C9A5E',
# }

# Edge color for bars (consistent across all figures)
EDGE_COLOR = '#2F2F2F'  # Dark gray, almost black
EDGE_WIDTH = 0.7

# Grid styling
GRID_STYLE = {
    'linestyle': '--',
    'alpha': 0.25,
    'color': '#888888',
    'linewidth': 0.8,
}

# Legend styling
LEGEND_STYLE = {
    'frameon': False,       # No frame for cleaner academic look
    'shadow': False,
    'fancybox': False,
}

# Font configuration
FONT_CONFIG = {
    'family': 'serif',
    'base_size': 18,
    'label_size': 22,
    'tick_size': 18,
    'legend_size': 18,
}

# Labels for legend
LABELS = {
    'baseline': 'Baseline',
    'tb_tbp': 'TB-TBP',
    'proposed': 'Proposed',
}
