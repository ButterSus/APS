set testbench     [lindex $argv 0]
set fpga_part     [lindex $argv 1]
set src_files     [lindex $argv 2]
set mem_files     [lindex $argv 3]
set test_files    [lindex $argv 4]
set wave_cfg_path [lindex $argv 5]

create_project -force sim ./sim_proj -part $fpga_part
set_param general.maxThreads 8

add_files -fileset sources_1 -norecurse $src_files
add_files -fileset sources_1 -norecurse $mem_files
add_files -fileset sim_1     -norecurse $test_files

set_property top $testbench [get_filesets sim_1]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Make "launch_simulation" not running
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

launch_simulation

# Try to fix it back, even though it doesn't work for some reason
set_property -name {xsim.simulate.runtime} -value {1s} -objects [get_filesets sim_1]

# Log everything by default
log_wave -recursive *

run all

if {$wave_cfg_path eq ""} {
    close_sim -force
} else {
    # If wave config provided, we interpret this as command to run waveforms
	if {[file exists $wave_cfg_path]} {
	    puts "Loading wave config..."
	    open_wave_config $wave_cfg_path
    }

	proc save_wcfg {} {
	    global wave_cfg_path
	    save_wave_config $wave_cfg_path
	    puts "Saved wave config."
	}

	puts "Please feel free to use 'save_wcfg' function to save your wave configuration"
}
