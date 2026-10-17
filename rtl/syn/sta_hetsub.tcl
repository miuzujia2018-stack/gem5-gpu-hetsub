# E3.1 OpenSTA timing check on the Yosys netlist (same flow as E1.2).
# Netlist post-processed by syn/fix_ports.py to restore liberty pin names.
read_liberty pdk/Nangate45_typ_yosys.lib
read_verilog syn/out_hetsub_netlist_fixed.v
link_design hetsub_tile_top
read_sdc syn/sdc_hetsub.sdc

report_wns
