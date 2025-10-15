# Vivado Build System
# Usage: make [target] TOP=module_name [options]
#        make [target] TB=module_name [options]

VIVADO := /tools/Xilinx/Vivado/2019.2/bin/vivado

# FPGA Configuration
FPGA_PART := xc7a100tcsg324-1

# Build Targets
SYNTH_DCP := $(BUILD_DIR)/out/synth.dcp
PLACE_DCP := $(BUILD_DIR)/out/place.dcp
ROUTE_DCP := $(BUILD_DIR)/out/route.dcp

# Source Files
SRC_FILES := $(wildcard $(SRC_DIR)/*.sv) $(wildcard $(SRC_DIR)/*.v) $(wildcard $(BOARD_DIR)/*.sv) $(wildcard $(BOARD_DIR)/*.v)
TEST_FILES := $(wildcard $(TEST_DIR)/*.sv) $(wildcard $(TEST_DIR)/*.v)
XDC_FILES := $(wildcard $(BOARD_DIR)/*.xdc)
MEM_FILES := $(wildcard $(SRC_DIR)/*.mem)

# Check required variables
.PHONY: check_top check_tb

check_top:
	@test -n "$(TOP)" || (echo "Error: TOP module required. Usage: make <target> TOP=module_name"; exit 1)

check_tb:
	@test -n "$(TB)" || (echo "Error: TB testbench required. Usage: make <target> TB=testbench_name"; exit 1)

# Main Targets
.PHONY: all quick synth impl bitstream program sim gui clean

# WARN: This is not imported automatically, so this shortcuts won't work in ./Labs
all: quick

quick: check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/quick.tcl \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES)" "$(MEM_FILES)" "$(XDC_FILES)"

synth: $(SYNTH_DCP)

impl: $(ROUTE_DCP)

bitstream: check_top $(ROUTE_DCP)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/bitstream.tcl -tclargs $(TOP)

program: check_top
	@test -f $(BUILD_DIR)/out/$(TOP).bit || (echo "Error: Bitstream not found. Run 'make bitstream TOP=$(TOP)' first"; exit 1)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/program.tcl -tclargs out/$(TOP).bit

sim: check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/sim.tcl \
		-tclargs $(TB) $(FPGA_PART) "$(SRC_FILES)" "$(MEM_FILES)" "$(TEST_FILES)"

sim_gui: check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO) -mode gui \
		-source $(TCL_DIR)/sim.tcl \
		-tclargs $(TB) $(FPGA_PART) "$(SRC_FILES)" "$(MEM_FILES)" "$(TEST_FILES)" gui

rtl: check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO) -mode gui \
		-source $(TCL_DIR)/rtl.tcl \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES)" "$(MEM_FILES)" "$(XDC_FILES)"

clean:
	rm -rf $(BUILD_DIR)

# Implementation Stages
$(SYNTH_DCP): check_top $(SRC_FILES) $(XDC_FILES) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/synth.tcl \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES)" "$(MEM_FILES)" "$(XDC_FILES)"

$(PLACE_DCP): $(SYNTH_DCP)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/place.tcl

$(ROUTE_DCP): $(PLACE_DCP)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace \
		-source $(TCL_DIR)/route.tcl

# Directory Creation
$(BUILD_DIR) $(BUILD_DIR)/out:
	mkdir -p $@
