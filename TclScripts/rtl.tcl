set top_module [lindex $argv 0]
set fpga_part  [lindex $argv 1]
set src_files  [lindex $argv 2]
set mem_files  [lindex $argv 3]
set xdc_files  [lindex $argv 4]

create_project -force rtl ./rtl_proj -part $fpga_part

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

foreach xdc $xdc_files {
    if {[file exists ../$xdc]} {
        add_files -fileset constrs_1 -norecurse ../$xdc
    }
}

set_property top $top_module [get_filesets sources_1]
set_property source_mgmt_mode All [current_project]

update_compile_order -fileset sources_1

synth_design -rtl -name rtl_1
show_schematic [get_cells]
