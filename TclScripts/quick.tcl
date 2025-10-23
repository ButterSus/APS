set top_module [lindex $argv 0]
set fpga_part  [lindex $argv 1]
set src_files  [lindex $argv 2]
set mem_files  [lindex $argv 3]
set xdc_files  [lindex $argv 4]

create_project -force quick ./quick_proj -part $fpga_part
set_param general.maxThreads 8

add_files -fileset sources_1 -norecurse $src_files $mem_files
add_files -fileset constrs_1 -norecurse $xdc_files

set_property top $top_module [get_filesets sources_1]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

synth_design -top $top_module \
    -part $fpga_part \
    -flatten_hierarchy rebuilt \
    -directive RuntimeOptimized \
    -no_timing_driven

opt_design   -directive RuntimeOptimized
place_design -directive RuntimeOptimized
route_design -directive RuntimeOptimized

write_bitstream -force out/${top_module}.bit

report_utilization    -file out/utilization.txt
report_timing_summary -file out/timing.txt
