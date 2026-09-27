set task_number [lindex $argv 0]
if {$task_number ni {9 15}} { error "Expected task 9 or 15" }
set_param general.maxThreads 4
read_verilog -sv src/tasks/task_${task_number}/task_${task_number}.sv
synth_design -top task_${task_number} -part xck26-sfvc784-2LV-c -mode out_of_context -directive RuntimeOptimized
create_clock -name task_clock -period 10 [get_ports i_clk]
report_utilization -file utilization_synth.rpt
report_timing_summary -file timing_synth.rpt
opt_design -directive RuntimeOptimized
place_design -directive RuntimeOptimized
route_design -directive RuntimeOptimized
report_utilization -file utilization_routed.rpt
report_timing_summary -file timing_routed.rpt
report_drc -file drc.rpt
puts "OOC_IMPLEMENTATION_COMPLETED task=$task_number"
