# Ultra-Fast Build Script
# Combines synth + place + route + bitstream in one pass

set top_module [lindex $argv 0]
set fpga_part [lindex $argv 1]
set src_files [lindex $argv 2]
set xdc_files [lindex $argv 3]

puts "========================================="
puts "Quick Build Mode - Optimized for Speed"
puts "Top Module: $top_module"
puts "========================================="

# Create project
create_project -force quick ./quick_proj -part $fpga_part

# Maximum threads
set_param general.maxThreads 8


# Add source files
foreach f $src_files {
    if {[file exists ../$f]} {
        add_files -norecurse ../$f
        # Explicitly set SystemVerilog for .sv files
        if {[string match "*.sv" $f]} {
            set_property file_type SystemVerilog [get_files ../$f]
        }
    }
}

# Add constraints
foreach xdc $xdc_files {
    if {[file exists ../$xdc]} {
        add_files -fileset constrs_1 -norecurse ../$xdc
    }
}


# Set top module
set_property top $top_module [current_fileset]

# Enable automatic source management and compile order
set_property source_mgmt_mode All [current_project]

# Update compile order - Vivado analyzes dependencies automatically
update_compile_order -fileset sources_1

# Run synthesis (fast mode)
puts "Running fast synthesis..."
synth_design -top $top_module \
    -part $fpga_part \
    -flatten_hierarchy rebuilt \
    -directive RuntimeOptimized \
    -no_timing_driven

# Run implementation (fast mode)
puts "Running fast place & route..."
opt_design -directive RuntimeOptimized
place_design -directive RuntimeOptimized
route_design -directive RuntimeOptimized

# Generate bitstream
puts "Generating bitstream..."
write_bitstream -force out/${top_module}.bit

# Quick reports
report_utilization -file out/utilization.txt
report_timing_summary -file out/timing.txt

puts "========================================="
puts "Quick build complete!"
puts "Bitstream: out/${top_module}.bit"
puts "========================================="