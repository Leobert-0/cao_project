# Run with Vivado 2022.2+: vivado -mode batch -source scripts/vivado_compare.tcl
# Optional: -tclargs xc7a35tcpg236-1
# Non-project OOC flow excludes IO buffers; the complete ALU is the top.
set root [file normalize [file join [file dirname [info script]] ..]]
cd $root
set part xc7a35tcpg236-1
if {$argc > 0} { set part [lindex $argv 0] }
set out [file join $root results vivado]
file mkdir $out
set summary [open [file join $out comparison.csv] w]
puts $summary "style,part,stage,cells,LUTs,CARRY4,worst_data_path_ns,status"
foreach style {structural behavioral} {
    set top alu_$style
    set dest [file join $out $style]
    file mkdir $dest
    create_project -in_memory -part $part
    set_property target_language Verilog [current_project]
    read_verilog -include_dirs [list [file join $root rtl]] [glob [file join $root rtl *.v]]
    synth_design -top $top -part $part -mode out_of_context -flatten_hierarchy rebuilt
    set_max_delay 10.000 -datapath_only -from [all_inputs] -to [all_outputs]
    report_utilization -file [file join $dest utilization_synth.rpt]
    if {[llength [get_cells -hier -filter {REF_NAME =~ LDCE* || REF_NAME =~ LDPE*}]] > 0} {
        error "Unexpected inferred latch in $style"
    }
    report_timing -from [all_inputs] -to [all_outputs] -max_paths 10 -file [file join $dest timing_synth.rpt]
    write_checkpoint -force [file join $dest synthesized.dcp]
    write_verilog -force -mode funcsim -rename_top alu_netlist [file join $dest functional_netlist.v]
    # OOC implementation yields internal routed delay, without board IO placement.
    opt_design
    place_design
    route_design
    report_utilization -file [file join $dest utilization_routed.rpt]
    report_timing -from [all_inputs] -to [all_outputs] -max_paths 10 -file [file join $dest timing_routed.rpt]
    report_drc -file [file join $dest drc.rpt]
    write_checkpoint -force [file join $dest routed.dcp]
    write_verilog -force -mode timesim -rename_top alu_netlist [file join $dest timing_netlist.v]
    write_sdf -force [file join $dest timing_netlist.sdf]
    set paths [get_timing_paths -from [all_inputs] -to [all_outputs] -max_paths 1]
    if {[llength $paths] == 0} { error "No constrained input/output timing path for $style" }
    set delay [get_property DATAPATH_DELAY [lindex $paths 0]]
    set cells [llength [get_cells -hier -filter {IS_PRIMITIVE == 1}]]
    set luts [llength [get_cells -hier -filter {REF_NAME =~ LUT*}]]
    set carry [llength [get_cells -hier -filter {REF_NAME == CARRY4}]]
    puts $summary "$style,$part,routed,$cells,$luts,$carry,$delay,measured"
    flush $summary
    close_project
    # XSim functional netlist verification (vendor primitives from unisims_ver).
    set previous [pwd]
    cd $dest
    exec xvlog functional_netlist.v [file join $root tb tb_post.v] > compile.log 2>@1
    set vf [open functional_netlist.v r]
    set nettext [read $vf]
    close $vf
    if {![regexp {module\s+glbl} $nettext]} {
        exec xvlog [file join $::env(XILINX_VIVADO) data verilog src glbl.v] >> compile.log 2>@1
    }
    exec xelab -L unisims_ver -L unimacro_ver tb_post glbl -s post_functional > elaborate.log 2>@1
    exec xsim post_functional -tclbatch [file join $root scripts post_run.tcl] > simulation.log 2>@1
    set sf [open simulation.log r]
    set simtext [read $sf]
    close $sf
    if {[string first {[PASS] tb_post} $simtext] < 0 || [string first {[FAIL]} $simtext] >= 0} {
        error "Post-synthesis functional test failed for $style; inspect $dest/simulation.log"
    }
    cd $previous
}
close $summary
puts "Comparison and post-synthesis functional results: $out"
