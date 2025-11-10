# MIT License
#
# Copyright (c) 2025 Krivoshapkin Eduard
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in all
# copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
# SOFTWARE.


# Vivado Build System
# Usage: make [target] TOP=module_name [options]
#        make [target] TB=module_name [options]

VIVADO_BIN := /tools/Xilinx/Vivado/2019.2/bin
ifeq ($(strip $(MACHINE)),1)
RV32_GCC_BIN = /home/buttersus/Dev/riscv/bin
else
RV32_GCC_BIN = /tools/riscv-dv/riscv-gnu-toolchain/build/riscv32/bin
endif

# FPGA Configuration
FPGA_PART := xc7a100tcsg324-1
ifeq ($(strip $(MACHINE)),1)
CFLAGS  := -march=rv32i_zicsr -mabi=ilp32 -Wl,--gc-sections -nostartfiles
CXXFLAGS  := -march=rv32i_zicsr -mabi=ilp32 -Wl,--gc-sections -nostartfiles
else
CFLAGS  := -march=rv32i -mabi=ilp32 -Wl,--gc-sections -nostartfiles
CXXFLAGS  := -march=rv32i -mabi=ilp32 -Wl,--gc-sections -nostartfiles
endif

# Build Targets
SYNTH_DCP := $(BUILD_DIR)/out/synth.dcp
PLACE_DCP := $(BUILD_DIR)/out/place.dcp
ROUTE_DCP := $(BUILD_DIR)/out/route.dcp

# Utilities
define rwildcard
  $(if $(strip $1), \
    $(foreach d,$(wildcard $(1)/*),$(call rwildcard,$d,$2)) \
    $(filter $(subst *,%,$2),$(wildcard $(1)/$(2))) \
  )
endef

# Source Files
RTL_FILES  := $(call rwildcard, $(RTL_DIR), *.sv) $(call rwildcard, $(RTL_DIR), *.v) $(call rwildcard, $(BOARD_DIR), *.sv) $(call rwildcard, $(BOARD_DIR), *.v)
TEST_FILES := $(call rwildcard, $(TEST_DIR), *.sv) $(call rwildcard, $(TEST_DIR), *.v)
XDC_FILES  := $(call rwildcard, $(BOARD_DIR), *.xdc)
MEM_FILES  := $(call rwildcard, $(RTL_DIR), *.mem)
ASM_FILES  := $(call rwildcard, $(RTL_DIR), *.asm)
STARTUP_FILE := $(SRC_DIR)/startup.S
C_FILES      := $(call rwildcard, $(SRC_DIR), *.c)
CPP_FILES    := $(call rwildcard, $(SRC_DIR), *.cpp)
INC_FILES    := $(call rwildcard, $(INC_DIR), *.h) $(call rwildcard, $(INC_DIR), *.hpp)

define realpath_safe
$(strip $(shell \
  trimmed=$$(echo $1 | xargs); \
  if [ -z "$$trimmed" ]; then \
    printf ''; \
  else \
    realpath -m --relative-to=$(BUILD_DIR) $1; \
  fi))
endef

# Intermediate and output dirs
ASM_DIR = $(BUILD_DIR)/asm
OUT_DIR = $(BUILD_DIR)/out
FIRMWARE_DIR = $(BUILD_DIR)/firmware

# Built Files
BUILT_ASM_FILES := $(patsubst $(RTL_DIR)/%.asm, $(OUT_DIR)/%.rom.mem, $(ASM_FILES)) \
				   $(patsubst $(RTL_DIR)/%.asm, $(OUT_DIR)/%.ram.mem, $(ASM_FILES))
ifeq ($(strip $(FIRMWARE_NAME)),)
  BUILT_FIRMWARE_FILES :=
else
  BUILT_FIRMWARE_FILES := $(OUT_DIR)/$(FIRMWARE_NAME).rom.mem $(OUT_DIR)/$(FIRMWARE_NAME).ram.mem
endif
ALL_MEM_FILES := $(MEM_FILES) $(BUILT_ASM_FILES) $(BUILT_FIRMWARE_FILES)
OBJ_FILES := $(patsubst $(SRC_DIR)/%.S,$(FIRMWARE_DIR)/%.S.o,$(STARTUP_FILE)) \
             $(patsubst $(SRC_DIR)/%.c,$(FIRMWARE_DIR)/%.c.o,$(C_FILES)) \
			 $(patsubst $(SRC_DIR)/%.cpp,$(FIRMWARE_DIR)/%.cpp.o,$(CPP_FILES))
$(info $$OBJ_FILES is [$(OBJ_FILES)])


# Paths relative to $(BUILD_DIR)
RTL_FILES_PATHS     := $(call realpath_safe,$(RTL_FILES))
TEST_FILES_PATHS    := $(call realpath_safe,$(TEST_FILES))
XDC_FILES_PATHS     := $(call realpath_safe,$(XDC_FILES))
XSIM_WCFG_PATH      := $(call realpath_safe,$(TEST_DIR)/xsim.wcfg)
ALL_MEM_FILES_PATHS := $(call realpath_safe,$(MEM_FILES) $(BUILT_ASM_FILES) $(BUILT_FIRMWARE_FILES))

# Tool prefixes
AS      = $(RV32_GCC_BIN)/riscv32-unknown-elf-as
GCC     = $(RV32_GCC_BIN)/riscv32-unknown-elf-gcc
G++     = $(RV32_GCC_BIN)/riscv32-unknown-elf-g++
LD      = $(RV32_GCC_BIN)/riscv32-unknown-elf-ld
OBJDUMP = $(RV32_GCC_BIN)/riscv32-unknown-elf-objdump
OBJCOPY = $(RV32_GCC_BIN)/riscv32-unknown-elf-objcopy
READELF = readelf


# PHONY TARGETS (Always rebuild)
# -------------

# Most of these just invoke TCL scripts.

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
.PHONY: quick synth impl bitstream program sim sim_gui rtl asm disasm clean

quick: $(ALL_MEM_FILES) --check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/quick.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(RTL_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(XDC_FILES_PATHS)"

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

sim: $(ALL_MEM_FILES) --check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/sim.tcl) \
		-tclargs $(TB) $(FPGA_PART) "$(RTL_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(TEST_FILES_PATHS)"

sim_gui: $(ALL_MEM_FILES) --check_tb | $(BUILD_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/sim.tcl) \
		-tclargs $(TB) $(FPGA_PART) "$(RTL_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" \
			"$(TEST_FILES_PATHS)" "$(XSIM_WCFG_PATH)"

rtl: $(ALL_MEM_FILES) --check_top | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/rtl.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(RTL_FILES_PATHS)" "$(ALL_MEM_FILES_PATHS)" "$(XDC_FILES_PATHS)"

asm: $(BUILT_ASM_FILES)

firmware: $(BUILT_FIRMWARE_FILES)

clean:
	rm -rf $(BUILD_DIR)


# Vivado explicit flow targets (super slow)
# ----------------------------

# Implementation Stages
$(SYNTH_DCP): --check_top $(RTL_FILES) $(MEM_FILES) $(ALL_MEM_FILES) $(XDC_FILES) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/synth.tcl) \
		-tclargs $(TOP) $(FPGA_PART) "$(RTL_FILES_PATHS)" "$(ALL_MEM_FILES)" "$(XDC_FILES_PATHS)"

$(PLACE_DCP): $(SYNTH_DCP) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/place.tcl)

$(ROUTE_DCP): $(PLACE_DCP) | $(BUILD_DIR)/out
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(shell realpath --relative-to $(BUILD_DIR) $(TCL_DIR)/route.tcl)


# Memory firmware targets
# -----------------------

$(FIRMWARE_DIR)/%.elf: $(OBJ_FILES) | $(BUILD_DIR)
	$(LD) -T $(TCL_DIR)/rv32g_harvard.ld -o $@ $(OBJ_FILES)
	$(OBJDUMP) -D $@ > $(FIRMWARE_DIR)/$*.dis
	$(READELF) -l $@ > $(FIRMWARE_DIR)/$*.segments.txt
	$(READELF) -S $@ > $(FIRMWARE_DIR)/$*.sections.txt
	$(READELF) -s $@ > $(FIRMWARE_DIR)/$*.symbols.txt

# Object files to ELF
$(BUILD_DIR)/%.elf: $(BUILD_DIR)/%.o | $(BUILD_DIR)
	$(LD) -T $(TCL_DIR)/rv32g_harvard.ld -o $@ $<
	$(OBJDUMP) -D $@ > $(BUILD_DIR)/$*.dis
	$(READELF) -l $@ > $(BUILD_DIR)/$*.segments.txt
	$(READELF) -S $@ > $(BUILD_DIR)/$*.sections.txt
	$(READELF) -s $@ > $(BUILD_DIR)/$*.symbols.txt

# ELF to binary files
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.rom.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary -j .text $< $@

$(BUILD_DIR)/%.ram.bin: $(BUILD_DIR)/%.elf
	$(OBJCOPY) -O binary -j .data -j .bss $< $@


# Assembly targets
# ----------------

# Assembly to Object files
$(ASM_DIR)/%.o: $(RTL_DIR)/%.asm | $(ASM_DIR)
	@mkdir -p $(dir $@)
	$(AS) -march=rv32i -o $@ $<

# Binary to memory files with endian conversion
$(OUT_DIR)/%.mem: $(ASM_DIR)/%.bin | $(OUT_DIR)
	@mkdir -p $(dir $@)
	xxd -p -c 4 $< | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $@


# Firmware (C++) targets
# ----------------------

# Compile startup.S to startup.o
$(FIRMWARE_DIR)/%.S.o: $(STARTUP_FILE) | $(FIRMWARE_DIR)
	$(GCC) $(CFLAGS) -c -o $@ $<

# Compile each C source file
$(FIRMWARE_DIR)/%.c.o: $(SRC_DIR)/%.c | $(FIRMWARE_DIR)
	$(GCC) $(CFLAGS) -I$(INC_DIR) -c -o $@ $<

# Compile each C++ source file
$(FIRMWARE_DIR)/%.cpp.o: $(SRC_DIR)/%.cpp | $(FIRMWARE_DIR)
	$(GCC) $(CXXFLAGS) -I$(INC_DIR) -c -o $@ $<

# Binary to memory files with endian conversion
$(OUT_DIR)/%.mem: $(FIRMWARE_DIR)/%.bin | $(OUT_DIR)
	@mkdir -p $(dir $@)
	xxd -p -c 4 $< | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $@


# Utilities
# ---------

# Directory creation rules
$(FIRMWARE_DIR) $(ASM_DIR) $(OUT_DIR) $(BUILD_DIR):
	mkdir -p $@
