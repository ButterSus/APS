# Vivado Build System
# Usage: make [target] TOP=module_name [options]
#        make [target] TB=module_name [options]

VIVADO_BIN := /tools/Xilinx/Vivado/2019.2/bin
RV32_GCC_BIN = /tools/riscv-dv/riscv-gnu-toolchain/build/riscv32/bin

# FPGA Configuration
FPGA_PART := xc7a100tcsg324-1

# Build Targets
SYNTH_DCP := $(BUILD_DIR)/out/synth.dcp
PLACE_DCP := $(BUILD_DIR)/out/place.dcp
ROUTE_DCP := $(BUILD_DIR)/out/route.dcp

# Utilities
rwildcard = $(foreach d,$(wildcard $(1)/*),$(call rwildcard,$d,$2)) $(filter $(subst *,%,$2),$(wildcard $(1)/$(2)))

# Source Files
SRC_FILES  := $(call rwildcard, $(SRC_DIR), *.sv) $(call rwildcard, $(SRC_DIR), *.v) $(call rwildcard, $(BOARD_DIR), *.sv) $(call rwildcard, $(BOARD_DIR), *.v)
TEST_FILES := $(call rwildcard, $(TEST_DIR), *.sv) $(call rwildcard, $(TEST_DIR), *.v)
XDC_FILES  := $(call rwildcard, $(BOARD_DIR), *.xdc)
MEM_FILES  := $(call rwildcard, $(SRC_DIR), *.mem)
ASM_FILES  := $(call rwildcard, $(SRC_DIR), *.asm)

define realpath_safe
$(strip $(shell \
  if [ -n "$1" ]; then \
    printf '%s\n' $1 | xargs -I{} realpath --relative-to=$(BUILD_DIR) "{}"; \
  fi))
endef

# Built Files
BUILT_ASM_FILES := $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/out/%.mem, $(ASM_FILES))
BUILT_ASM_FILES_ROM := $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/out/%.rom.mem, $(ASM_FILES))
BUILT_ASM_FILES_RAM := $(patsubst $(SRC_DIR)/%.asm, $(BUILD_DIR)/out/%.ram.mem, $(ASM_FILES))

# Paths relative to $(BUILD_DIR)
SRC_FILES_PATHS     := $(call realpath_safe,$(SRC_FILES))
TEST_FILES_PATHS    := $(call realpath_safe,$(TEST_FILES))
XDC_FILES_PATHS     := $(call realpath_safe,$(XDC_FILES))
ALL_MEM_FILES_PATHS := $(call realpath_safe,$(MEM_FILES) $(BUILT_ASM_FILES_ROM) $(BUILT_ASM_FILES_RAM))
XSIM_WCFG_PATH      := $(call realpath_safe,$(TEST_DIR)/xsim.wcfg)

# Help function
.PHONY: help
help:
	@echo "Vivado Build System"
	@echo "Usage: make [target] TOP=module_name [options]"
	@echo "       make [target] TB=testbench_name [options]"
	@echo ""
	@echo "Targets:"
	@echo "  quick      - Quick synthesis and implementation"
	@echo "  synth      - Run synthesis only"
	@echo "  impl       - Run implementation"
	@echo "  bitstream  - Generate bitstream"
	@echo "  program    - Program FPGA"
	@echo "  sim        - Run simulation (batch)"
	@echo "  sim_gui    - Run simulation (GUI)"
	@echo "  rtl        - Open RTL viewer"
	@echo "  asm        - Build assembly files"
	@echo "  clean      - Remove build directory"

# Check required variables
.PHONY: --check_top --check_tb

--check_top:
	@test -n "$(TOP)" || (echo "Error: TOP module required. Usage: make <target> TOP=module_name"; exit 1)

--check_tb:
	@test -n "$(TB)" || (echo "Error: TB testbench required. Usage: make <target> TB=testbench_name"; exit 1)

# Main Targets
.PHONY: quick synth impl bitstream program sim sim_gui rtl asm clean

quick: --check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/quick.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(XDC_FILES_PATHS)"

synth: $(SYNTH_DCP)

impl: $(ROUTE_DCP)

bitstream: --check_top $(ROUTE_DCP) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/bitstream.tcl) \
		-tclargs $(TOP)

program: --check_top
	@test -f $(BUILD_DIR)/out/$(TOP).bit || (echo "Error: Bitstream not found. Run 'make bitstream TOP=$(TOP)' first"; exit 1)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/program.tcl) \
		-tclargs out/$(TOP).bit

sim: $(BUILT_ASM_FILES) --check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/sim.tcl) \
		-tclargs $(TB) $(FPGA_PART) "$(SRC_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(TEST_FILES_PATHS)"

sim_gui: $(BUILT_ASM_FILES) --check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/sim.tcl) \
		-tclargs $(TB) $(FPGA_PART) "$(SRC_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" \
			"$(TEST_FILES_PATHS)" "$(XSIM_WCFG_PATH)"

rtl: $(BUILT_ASM_FILES) --check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/rtl.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(XDC_FILES_PATHS)"

asm: $(BUILT_ASM_FILES)

clean:
	rm -rf $(BUILD_DIR)

# Implementation Stages
$(SYNTH_DCP): --check_top $(SRC_FILES) $(MEM_FILES) $(BUILT_ASM_FILES) $(XDC_FILES) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/synth.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(SRC_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(XDC_FILES_PATHS)"

$(PLACE_DCP): $(SYNTH_DCP) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/place.tcl)

$(ROUTE_DCP): $(PLACE_DCP) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/route.tcl)

# This task will produce both normal mem images, and separated hardvard ones
$(BUILD_DIR)/out/%.mem: $(SRC_DIR)/%.asm | $(BUILD_DIR)/out $(BUILD_DIR)/asm
	$(RV32_GCC_BIN)/riscv32-unknown-elf-as -march=rv32i -o $(BUILD_DIR)/asm/$*.o $<
	$(RV32_GCC_BIN)/riscv32-unknown-elf-ld -T $(TCL_DIR)/rv32g_harvard.ld \
		-o $(BUILD_DIR)/asm/$*.elf $(BUILD_DIR)/asm/$*.o
	$(RV32_GCC_BIN)/riscv32-unknown-elf-objdump -D $(BUILD_DIR)/asm/$*.elf > $(BUILD_DIR)/out/$*.dis
	readelf -l $(BUILD_DIR)/asm/$*.elf > $(BUILD_DIR)/out/$*.segments.txt
	readelf -S $(BUILD_DIR)/asm/$*.elf > $(BUILD_DIR)/out/$*.sections.txt
	readelf -s $(BUILD_DIR)/asm/$*.elf > $(BUILD_DIR)/out/$*.symbols.txt
	$(RV32_GCC_BIN)/riscv32-unknown-elf-objcopy -O binary $(BUILD_DIR)/asm/$*.elf $(BUILD_DIR)/asm/$*.bin
	$(RV32_GCC_BIN)/riscv32-unknown-elf-objcopy -O binary -j .text $(BUILD_DIR)/asm/$*.elf $(BUILD_DIR)/asm/$*.rom.bin
	$(RV32_GCC_BIN)/riscv32-unknown-elf-objcopy -O binary -j .data -j .bss -j .rodata $(BUILD_DIR)/asm/$*.elf $(BUILD_DIR)/asm/$*.ram.bin
	xxd -p -c 4 $(BUILD_DIR)/asm/$*.bin | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $(BUILD_DIR)/out/$*.mem
	xxd -p -c 4 $(BUILD_DIR)/asm/$*.rom.bin | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $(BUILD_DIR)/out/$*.rom.mem
	xxd -p -c 4 $(BUILD_DIR)/asm/$*.ram.bin | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $(BUILD_DIR)/out/$*.ram.mem

# Directory Creation
$(BUILD_DIR) $(BUILD_DIR)/out $(BUILD_DIR)/asm:
	mkdir -p $@
