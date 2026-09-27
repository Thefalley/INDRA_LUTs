# Diagnostic only: does not alter official project or timing constraints.
set root [file normalize [lindex $argv 0]]
set files [glob $root/src/tasks/task_16/*.sv]
read_verilog -sv $files
synth_design -top task_16 -part xck26-sfvc784-2LV-c -mode out_of_context -directive RuntimeOptimized
create_clock -name clk -period 10 [get_ports i_clk]
set_input_delay 1 -clock clk [get_ports {i_rst i_valid i_last i_data* i_keep* o_ready}]
set_output_delay 1 -clock clk [get_ports {i_ready o_valid o_last o_data* o_keep*}]
opt_design -directive RuntimeOptimized
place_design -directive RuntimeOptimized
route_design -directive RuntimeOptimized
report_utilization -file utilization.rpt
report_timing_summary -file timing.rpt
report_timing -from [get_ports o_ready] -to [get_ports i_ready] -file ready_path.rpt
write_checkpoint -force packer.dcp
exit
