"""
Academic Color Scheme Configuration
Shared color palette for all visualization scripts
Based on professional academic publication standards

New Color Scheme (2026-01-06):
- Baseline: #003B5C (Dark blue) - Solid line
- OSCAR: #FF6633 (Orange) - Solid line
- Shortcut: #F9D84B (Yellow) - Dashed line
- FTBY: #88C649 (Green) - Solid line
- FTYBY_PG: #0095D9 (Bright blue) - Dashed line
- Adapt-NoC-nRL: #882D99 (Purple) - Hollow/Open
- Adapt-NoC: #FA7B2E (Light orange) - Dashed line
"""

# Primary color scheme for 3-column charts (Baseline, TB-TBP, Proposed)
COLORS = {
    'baseline': '#003B5C',      # Baseline - Dark blue
    'tb_tbp': '#88C649',        # FTBY - Green
    'proposed': '#FA7B2E',      # Adapt-NoC - Light orange
}

# Extended color scheme for 6-column charts
COLORS_6 = {
    'Baseline': '#003B5C',      # Baseline - Dark blue
    'VIX': '#FF6633',           # OSCAR - Orange
    'DIP': '#F9D84B',           # Shortcut - Yellow
    'O1TURN': '#88C649',        # FTBY - Green
    'OSCAR': '#0095D9',         # FTYBY_PG - Bright blue
    'ALPHA': '#FA7B2E',         # Adapt-NoC - Light orange
    'Proposed': '#FA7B2E',      # Adapt-NoC - Light orange (alias)
}

# Complete palette for all methods
FULL_PALETTE = {
    'baseline': '#003B5C',      # Baseline
    'oscar': '#FF6633',         # OSCAR
    'shortcut': '#F9D84B',      # Shortcut
    'ftby': '#88C649',          # FTBY
    'ftyby_pg': '#0095D9',      # FTYBY_PG
    'adapt_noc_nrl': '#882D99', # Adapt-NoC-nRL
    'adapt_noc': '#FA7B2E',     # Adapt-NoC
}

# Line styles for different methods (for line charts)
LINE_STYLES = {
    'baseline': '-',            # Solid
    'oscar': '-',               # Solid
    'shortcut': '--',           # Dashed
    'ftby': '-',                # Solid
    'ftyby_pg': '--',           # Dashed
    'adapt_noc_nrl': '-',       # Solid (with hollow markers)
    'adapt_noc': '--',          # Dashed
}

# Marker styles (for line/scatter plots)
MARKER_STYLES = {
    'baseline': 'o',            # Circle
    'oscar': 's',               # Square
    'shortcut': '^',            # Triangle up
    'ftby': 'D',                # Diamond
    'ftyby_pg': 'v',            # Triangle down
    'adapt_noc_nrl': 'o',       # Hollow circle
    'adapt_noc': 'p',           # Pentagon
}

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
    'tb_tbp': 'FTBY',           # Changed from TB-TBP
    'proposed': 'Adapt-NoC',    # Changed from Proposed
}
