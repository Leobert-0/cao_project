# Vivado Tcl Console: source scripts/create_vivado_project.tcl
# Batch: vivado -mode batch -source scripts/create_vivado_project.tcl
set root [file normalize [file join [file dirname [info script]] ..]]
set project_dir [file join $root .build vivado_gui]
create_project -force cao_alu_suite $project_dir -part xc7a35tcpg236-1
add_files [glob [file join $root rtl *.v]]
set_property include_dirs [list [file join $root rtl]] [get_filesets sources_1]
set_property top demo_datapath [get_filesets sources_1]
add_files -fileset sim_1 [glob [file join $root tb *.v]]
set_property include_dirs [list [file join $root rtl] [file join $root vectors]] [get_filesets sim_1]
set_property top tb_top [get_filesets sim_1]
# Testbenches use root-relative paths for portable .mem/.vcd access.
set_property xsim.simulate.tcl.pre [file join $root scripts xsim_workdir.tcl] [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
puts "Project ready: $project_dir/cao_alu_suite.xpr"
puts "Run Simulation > Run Behavioral Simulation; top is tb_top."
