set root [file normalize [file join [file dirname [info script]] ../..]]
read_verilog -sv [file join $root src/tasks/task_15/task_15.sv]
synth_design -top task_15 -part xck26-sfvc784-2LV-c -mode out_of_context
create_clock -period 10 [get_ports i_clk]
report_utilization -file utilization.rpt
report_timing_summary -file timing_synth.rpt
write_checkpoint -force task15_synth.dcp
puts TASK15_SYNTH_PASS
