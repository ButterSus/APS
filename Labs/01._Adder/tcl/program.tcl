# FPGA Programming Script
# This script programs the FPGA using Vivado Lab Edition

set bitstream_file [lindex $argv 0]

puts "========================================="
puts "FPGA Programming Script"
puts "Bitstream: $bitstream_file"
puts "========================================="

# Check if bitstream file exists
if {![file exists $bitstream_file]} {
    puts "ERROR: Bitstream file not found: $bitstream_file"
    exit 1
}

# Open hardware manager
open_hw_manager

puts "Connecting to hardware server..."
connect_hw_server -allow_non_jtag

# Get the first available hardware target
puts "Opening hardware target..."
set hw_targets [get_hw_targets]
if {[llength $hw_targets] == 0} {
    puts "ERROR: No hardware targets found"
    puts "Make sure your FPGA board is connected and powered on"
    close_hw_manager
    exit 1
}

# Open the first target
open_hw_target [lindex $hw_targets 0]

# Get the first device
set hw_devices [get_hw_devices]
if {[llength $hw_devices] == 0} {
    puts "ERROR: No hardware devices found on target"
    close_hw_target
    close_hw_manager
    exit 1
}

set hw_device [lindex $hw_devices 0]
puts "Programming device: $hw_device"

# Set the bitstream file
current_hw_device $hw_device
set_property PROGRAM.FILE $bitstream_file $hw_device

# Program the device
puts "Programming FPGA..."
program_hw_devices $hw_device

# Verify programming
if {[get_property PROGRAM.DONE $hw_device]} {
    puts "========================================="
    puts "SUCCESS: FPGA programmed successfully!"
    puts "========================================="
} else {
    puts "========================================="
    puts "ERROR: FPGA programming failed!"
    puts "========================================="
    close_hw_target
    close_hw_manager
    exit 1
}

# Cleanup
close_hw_target
close_hw_manager

puts "Done."