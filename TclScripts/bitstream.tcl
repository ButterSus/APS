set top_module [lindex $argv 0]

open_checkpoint out/route.dcp
write_bitstream -force out/${top_module}.bit
