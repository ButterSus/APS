set tb_file [lindex $argv 0]
set fpga_part [lindex $argv 1]
set src_files [lindex $argv 2]
set gui_mode [lindex $argv 3]

# Create simulation project
create_project -force sim ./sim_proj -part $fpga_part

# Add source files
foreach f $src_files {
    add_files -norecurse ../$f
}

# Add testbench
if {[file exists ../$tb_file]} {
    add_files -fileset sim_1 -norecurse ../$tb_file
} else {
    puts "ERROR: Testbench file not found: $tb_file"
    exit 1
}

# Parse testbench name (convert dots to underscores to match module name)
set tb_name [file tail $tb_file]
set tb_name [regsub {\.sv$} $tb_name ""]
set tb_name [regsub -all {\.} $tb_name "_"]

# Set the testbench as top module for simulation
set_property top $tb_name [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property source_mgmt_mode All [current_project]

# Update compile order
update_compile_order -fileset sim_1

# Launch simulation
launch_simulation

# If batch mode, run and close
if {$gui_mode eq ""} {
    run all
    close_sim -force
} else {
    # GUI mode - just open, don't run or close
    puts "GUI mode: Simulation ready. Use GUI controls to run simulation."
}