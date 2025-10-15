set bitstream_file [lindex $argv 0]

if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream not found: $bitstream_file"
    exit 1
}

open_hw_manager
connect_hw_server -allow_non_jtag

set hw_targets [get_hw_targets]
if {[llength $hw_targets] == 0} {
    puts "ERROR: No hardware targets found"
    close_hw_manager
    exit 1
}

open_hw_target [lindex $hw_targets 0]

set hw_devices [get_hw_devices]
if {[llength $hw_devices] == 0} {
    puts "ERROR: No devices found"
    close_hw_target
    close_hw_manager
    exit 1
}

set hw_device [lindex $hw_devices 0]
current_hw_device $hw_device
set_property PROGRAM.FILE $bitstream_file $hw_device

program_hw_devices $hw_device

if {![get_property PROGRAM.DONE $hw_device]} {
    puts "ERROR: Programming failed"
    close_hw_target
    close_hw_manager
    exit 1
}

close_hw_target
close_hw_manager
