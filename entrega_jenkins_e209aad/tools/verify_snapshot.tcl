# Usage: vivado -mode batch -source verify_snapshot.tcl -tclargs <clone-root>
# Copies of tb_lite differ ONLY in its documented TASK selector.
if {[llength $argv] != 1} {puts stderr "Expected the clone root as the only argument"; exit 2}
set repo [file normalize [lindex $argv 0]]
set argv {}; set argc 0
set fh [open $repo/src/task_enabler_pkg.svh r]
set enables [read $fh]; close $fh
set tasks {}
foreach {match n} [regexp -all -inline {task([0-9]+)\s*:\s*1'b1} $enables] {
    if {$n ni {1 2 3 5 7 8 9 10 11 12 13 14 15 16}} {error "Unsupported tb_lite task: $n"}
    lappend tasks $n
}
if {![llength $tasks]} {error "No FPGA tasks enabled"}
set tasks [lsort -integer -unique $tasks]
set out [file join [file dirname $repo] local_results [file tail $repo]_[clock format [clock seconds] -format %Y%m%d_%H%M%S]_[pid]]
file mkdir $out
set fh [open $out/manifest.txt w]
puts $fh "repo=$repo\ntasks=$tasks\nclock=official testbench\nmax_simulation_us_per_task=5000"
if {![catch {exec git -C $repo rev-parse HEAD} revision]} {puts $fh "commit=$revision"}
if {![catch {exec git -C $repo status --porcelain} dirty]} {puts $fh "status_before_project_creation=$dirty"}
close $fh
puts "VERIFY_OUTPUT=$out"
set fh [open $repo/tb/tb_lite.sv r]
set bench [read $fh]; close $fh
if {[regexp -all -line {^\s*`define TASK_[0-9]+\s*$} $bench] != 1} {error "Expected exactly one active task selector in official tb_lite"}
foreach n $tasks {
    set variant $out/variants/task_$n
    file mkdir $variant
    regsub -line {^\s*`define TASK_[0-9]+\s*$} $bench "  `define TASK_$n" copy
    set fh [open $variant/tb_lite.sv w]; puts -nonewline $fh $copy; close $fh
}
set_param general.maxThreads 2
cd $out
set origin_dir_loc $repo/vivado
if {[catch {
    source $repo/vivado/hackathon.tcl
    set_property target_simulator XSim [current_project]
    set_property top tb_lite [get_filesets sim_1]
    set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
    set_property include_dirs [list $repo/tb $repo/src] [get_filesets sim_1]
    generate_target simulation [get_ips axi_vip_0]
} reason]} {puts "OFFICIAL_SETUP_FAIL=$reason"; exit 1}
set selected [get_files -of_objects [get_filesets sim_1] *tb_lite.sv]
set any_failure 0
foreach n $tasks {
    puts "OFFICIAL_TASK_BEGIN=$n"
    set task_out $out/task_$n
    file mkdir $task_out
    catch {close_sim}
    if {[llength $selected]} {remove_files -fileset sim_1 $selected}
    set selected $out/variants/task_$n/tb_lite.sv
    add_files -fileset sim_1 -norecurse $selected
    set_property file_type SystemVerilog [get_files $selected]
    update_compile_order -fileset sim_1
    set log $out/hackathon/hackathon.sim/sim_1/behav/xsim/simulate.log
    set result ""
    set failed [catch {
        launch_simulation -simset sim_1 -mode behavioral
        for {set step 0} {$step < 50} {incr step} {
            run 100us
            puts "OFFICIAL_PROGRESS task=$n elapsed_us=[expr {100*($step+1)}]"
            if {[file exists $log]} {
                set fh [open $log r]; set result [read $fh]; close $fh
                if {[string first "Testbench finished" $result] >= 0 || [string first "TEST FAILED!" $result] >= 0} {break}
            }
        }
    } reason]
    if {!$failed && [file exists $log]} {file copy $log $task_out/simulate.log}
    if {$failed} {
        set verdict ERROR
        puts "OFFICIAL_TASK_ERROR=$n reason=$reason"
    } elseif {[string first "TEST FAILED!" $result] >= 0} {
        set verdict FAIL
    } elseif {[string first "TEST PASSED!" $result] >= 0 && [string first "Testbench finished" $result] >= 0} {
        set verdict PASS
    } else {
        set verdict INCOMPLETE
    }
    if {$verdict ne "PASS"} {set any_failure 1}
    set fh [open $task_out/status.txt w]; puts $fh $verdict; close $fh
    puts "OFFICIAL_TASK_${verdict}=$n"
    catch {close_sim}
}
puts "OFFICIAL_SUITE_FINISHED failures=$any_failure"
exit $any_failure
