set top_module [lindex $argv 0]
set fpga_part [lindex $argv 1]

# Collect all files (arguments starting from index 2)
set all_files [lrange $argv 2 end]

# Read all Verilog/SystemVerilog files
foreach f $all_files {
    if {[string match "*.sv" $f] || [string match "*.v" $f]} {
        read_verilog -sv ../$f
    }
}

# Read all constraint files
foreach f $all_files {
    if {[string match "*.xdc" $f]} {
        read_xdc ../$f
    }
}

synth_design -top $top_module -part $fpga_part

write_checkpoint -force out/synth.dcp