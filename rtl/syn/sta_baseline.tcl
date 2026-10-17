# E1.2 OpenSTA timing check on the Yosys netlist (same flow as E3.1).
# The bridge re-import names abc-created cells by abc node names, so the netlist
# is post-processed by syn/fix_ports.py to restore liberty pin names before
# linking. Instances whose pin mapping is unrecoverable remain unlinked; WNS is
# reported on the linkable subset (see fix_ports.py output count).
read_liberty pdk/Nangate45_typ_yosys.lib
read_verilog syn/out_baseline_netlist_fixed.v
link_design baseline_router
read_sdc syn/sdc_baseline.sdc

report_wns
