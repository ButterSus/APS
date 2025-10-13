# Vivado Makefile

# Tools
# -----

VIVADO := /tools/Xilinx/Vivado/2019.2/bin/vivado


# Directories
# -----------

SRC_DIR   := src
TEST_DIR  := test
BOARD_DIR := board_files
BUILD_DIR := build
TCL_DIR   := ../../../TclScripts


# Implementation details
# ----------------------

FPGA_PART  := xc7a100tcsg324-1
# Specify: <TOP_MODULE>
# Specify: <TESTBENCH>

# For synthesis task
MODE       ?= DESIGN


# Grep files
# ----------

SRC_FILES  := $(wildcard $(SRC_DIR)/*.sv) $(wildcard $(SRC_DIR)/*.v)
TEST_FILES := $(wildcard $(TEST_DIR)/*.sv) $(wildcard $(TEST_DIR)/*.v)
XDC_FILES  := $(wildcard $(BOARD_DIR)/*.xdc)


# Targets
# -------

SYNTH_DCP := $(BUILD_DIR)/out/synth.dcp
PLACE_DCP := $(BUILD_DIR)/out/place.dcp
ROUTE_DCP := $(BUILD_DIR)/out/route.dcp
BITSTREAM := $(BUILD_DIR)/out/$(TOP_MODULE).bit


# Shortcuts
# ---------

# These are aliases for convenience
.PHONY: all quick synth place route bitstream program sim clean

# By default, run fastest workflow
all: quick

# Quick build - single step synthesis to bitstream (fastest)
quick: $(SRC_FILES) $(XDC_FILES) | $(BUILD_DIR) $(BUILD_DIR)/out
	@if [ -z "$(TOP_MODULE)" ]; then \
		echo "Error: Please specify a top module with TOP_MODULE=<basename>"; \
		echo "Example: make quick TOP_MODULE=my_top"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace -source $(TCL_DIR)/quick.tcl \
		-tclargs $(TOP_MODULE) $(FPGA_PART) "$(SRC_FILES)" "$(XDC_FILES)"

# Synthesis
synth: $(SYNTH_DCP)

# Placement
place: $(PLACE_DCP)

# Routing
route: $(ROUTE_DCP)

# Bitstream generation
bitstream: $(BITSTREAM)

# Simulation
# Note: If errors are encountered, they won't be
# printed if mode is set to gui
sim: $(SRC_FILES) $(TEST_FILES) | $(BUILD_DIR)
	@if [ -z "$(TESTBENCH)" ]; then \
		echo "Error: Please specify a testbench with TESTBENCH=<filename>"; \
		echo "Example: make sim TESTBENCH=my_test.sv"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && $(VIVADO) -mode $(if $(GUI),gui,batch) \
		-source $(TCL_DIR)/sim.tcl -notrace \
		-tclargs $(TEST_DIR)/$(TESTBENCH) $(FPGA_PART) "$(SRC_FILES)" $(if $(GUI),gui,)


# Tasks
# -----

$(SYNTH_DCP): $(SRC_FILES) $(XDC_FILES) | $(BUILD_DIR) $(BUILD_DIR)/out
	@if [ -z "$(TOP_MODULE)" ]; then \
		echo "Error: Please specify a top module with TOP_MODULE=<basename>"; \
		echo "Example: make [synth] TOP_MODULE=my_top"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace -source $(TCL_DIR)/synth.tcl \
		-tclargs $(TOP_MODULE) $(FPGA_PART) $(MODE) $(SRC_FILES) $(XDC_FILES)

$(PLACE_DCP): $(SYNTH_DCP)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace -source $(TCL_DIR)/place.tcl

$(ROUTE_DCP): $(PLACE_DCP)
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace -source $(TCL_DIR)/route.tcl

$(BITSTREAM): $(ROUTE_DCP)
	@if [ -z "$(TOP_MODULE)" ]; then \
		echo "Error: Please specify a top module with TOP_MODULE=<basename>"; \
		echo "Example: make [bitstream] TOP_MODULE=my_top"; \
		exit 1; \
	fi
	cd $(BUILD_DIR) && $(VIVADO) -mode batch -notrace -source $(TCL_DIR)/bitstream.tcl \
		-tclargs $(TOP_MODULE)

# Create build directories
$(BUILD_DIR):
	mkdir -p $(BUILD_DIR)

$(BUILD_DIR)/out:
	mkdir -p $(BUILD_DIR)/out

# Clean
clean:
	rm -rf $(BUILD_DIR)
