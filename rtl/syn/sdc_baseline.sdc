create_clock -name clk -period 1.0 [get_ports clk]
# Bound every path: inputs and outputs get explicit delays so no path is unconstrained.
set_input_delay 0 -clock clk [all_inputs]
set_output_delay 0 -clock clk [all_outputs]
