set testbench  [lindex $argv 0]
set fpga_part  [lindex $argv 1]
set src_files  [lindex $argv 2]
set mem_files  [lindex $argv 3]
set test_files [lindex $argv 4]
set gui_mode   [lindex $argv 5]

create_project -force sim ./sim_proj -part $fpga_part
set_param general.maxThreads 8

foreach src $src_files {
    if {[file exists ../$src]} {
        add_files -fileset sources_1 -norecurse ../$src
    }
}

foreach mem $mem_files {
    if {[file exists ../$mem]} {
        add_files -fileset sources_1 -norecurse ../$mem
    }
}

foreach test $test_files {
    if {[file exists ../$test]} {
        add_files -fileset sim_1 -norecurse ../$test
    }
}

set_property top $testbench [get_filesets sim_1]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

# Make "launch_simulation" run only for 0ns instead of till $finish
set_property -name {xsim.simulate.runtime} -value {0ns} -objects [get_filesets sim_1]

launch_simulation
log_wave -recursive *
run all

if {$gui_mode ne "gui"} {
    close_sim -force
}
