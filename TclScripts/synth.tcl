set top_module [lindex $argv 0]
set fpga_part [lindex $argv 1]
set mode [lindex $argv 2]
set all_files [lrange $argv 3 end]

# Create project based on GUI mode
if {$mode eq "RTL"} {
    # On-disk project for GUI exploration with Flow Navigator
    create_project -force synth_project ./synth_proj -part $fpga_part
} elseif {$mode eq "DESIGN"} {
    # In-memory project for fast batch builds
    create_project -in_memory -part $fpga_part
}

# Add all source files
foreach f $all_files {
    if {[string match "*.sv" $f] || [string match "*.v" $f]} {
        add_files -norecurse ../$f
        set_property file_type SystemVerilog [get_files ../$f]
    } elseif {[string match "*.xdc" $f]} {
        add_files -fileset constrs_1 -norecurse ../$f
    }
}

# Set top module
set_property top $top_module [current_fileset]

# Enable automatic source management, this is usually
# enabled by default for projects, but since we created
# temporary project via CLI, we need to specify it
# explicitly. Note, that we create project in synth.tcl only
# because we want to use Vivado's smart ordering capabilities.
# It was kinda surprising that Vivado can't compile without
# correct order.
set_property source_mgmt_mode All [current_project]

# Update compile order - Vivado analyzes dependencies
update_compile_order -fileset sources_1

# It turns out there are 2 different synth_design tasks, one is called elaboration,
# while another one is called synthesis of design. Elaboration has nothing to do
# with bitstream generation and FPGA, it's just a visual beautiful dump of code
# as RTL diagram.
if {$mode eq "RTL"} {
    # Open elaborated design (RTL view)
    synth_design -rtl -name rtl_1

    # Open schematic view of elaborated design
    show_schematic [get_cells]

    start_gui
} elseif {$mode eq "DESIGN"} {
    # Synthesize with automatic compile order
    synth_design -top $top_module

    write_checkpoint -force out/synth.dcp
}