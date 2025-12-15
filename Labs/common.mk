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


# --------------
# Configure this

VIVADO_BIN := /tools/Xilinx/Vivado/2019.2/bin
RV32_GCC_BIN := /home/buttersus/Dev/riscv/bin
RV32_GCC_PREFIX := riscv32-unknown-elf
CFLAGS  := -march=rv32i_zicsr -mabi=ilp32 -Wl,--gc-sections -nostartfiles
CXXFLAGS  := -march=rv32i_zicsr -mabi=ilp32 -Wl,--gc-sections -nostartfiles

# FPGA Configuration (Nexys A7)
FPGA_PART := xc7a100tcsg324-1

# Few requirements:
# 0. MEM_OUT_DIR can be anywhere
# 1. Script uses absolute directories, so any spaces in absolute path will ruin it
# 2. STARTUP_FILE must be in SRC_DIRS
# 3. ASM_OUT_DIR, FIRMWARE_OUT_DIR should be in BUILD_DIR


# ----------------------------------------------------------
# For compatibility with older projects (remove if not used)

ifdef LEGACY
  # Flexible source directories (space-separated for multiples)
  RTL_DIRS      ?= $(RTL_DIR) $(BOARD_DIR)
  TB_DIRS       ?= $(TB_DIR)
  BOARD_DIRS    ?= $(BOARD_DIR)
  MEM_DIRS      ?= $(RTL_DIR) $(TB_DIR)
  ASM_DIRS      ?= $(RTL_DIR) $(TB_DIR)
  SRC_DIRS      ?= $(SRC_DIR)
  INC_DIRS      ?= $(INC_DIR)
  SCRIPTS_DIR   ?= $(TCL_DIR)

  XSIM_WCFG     ?= $(TB_DIR)/xsim.wcfg
  STARTUP_FILE  ?= $(SRC_DIR)/startup.S

  # Output subdirectories
  OUT_DIR          ?= $(BUILD_DIR)/out
  MEM_OUT_DIR      ?= $(OUT_DIR)/mem
  ASM_OUT_DIR      ?= $(OUT_DIR)/asm
  FIRMWARE_OUT_DIR ?= $(FIRMWARE_DIR)
else
ifdef RTL_DIR
  $(error Perhaps, you forgot to set LEGACY := 1 ..?)
endif
endif

# Utilities
define rwildcard
$(if $(strip $1), \
  $(foreach d,$(wildcard $(1)/*),$(call rwildcard,$d,$2)) \
  $(filter $(subst *,%,$2),$(wildcard $(1)/$(2))) \
)
endef

define relpath
$(strip $(shell \
  if [ -z "$(strip $1)" ]; then \
    printf ''; \
  else \
    realpath -m --relative-to=$2 $1; \
  fi))
endef

define src_to_obj
$(strip \
  $(foreach f,$1, \
    $(foreach d,$2, \
      $(if $(filter $(d)/%,$(f)), \
        $(addprefix $3/,$(patsubst $4,$5,$(patsubst $(d)/%,%,$(f)))) \
      ) \
    ) \
  ) \
)
endef

# Source Files - supports multiple directories
RTL_FILES := $(foreach dir,$(RTL_DIRS),$(call rwildcard,$(dir),*.sv *.v))
TB_FILES  := $(foreach dir,$(TB_DIRS),$(call rwildcard,$(dir),*.sv *.v))
XDC_FILES := $(foreach dir,$(BOARD_DIRS),$(call rwildcard,$(dir),*.xdc))
MEM_FILES := $(foreach dir,$(MEM_DIRS),$(call rwildcard,$(dir),*.mem))
ASM_FILES := $(foreach dir,$(ASM_DIRS),$(call rwildcard,$(dir),*.asm))
C_FILES   := $(foreach dir,$(SRC_DIRS),$(call rwildcard,$(dir),*.c))
CPP_FILES := $(foreach dir,$(SRC_DIRS),$(call rwildcard,$(dir),*.cpp))
INC_FILES := $(foreach dir,$(INC_DIRS),$(call rwildcard,$(dir),*.h *.hpp))

INC_FLAGS := $(foreach d,$(INC_DIRS),-I$(d))

# Build Targets
SYNTH_DCP := $(OUT_DIR)/synth.dcp
PLACE_DCP := $(OUT_DIR)/place.dcp
ROUTE_DCP := $(OUT_DIR)/route.dcp

# Built Files - organized by type
BUILT_ASM_ROMS       := $(call src_to_obj,$(ASM_FILES),$(ASM_DIRS),$(MEM_OUT_DIR),%.asm,%.rom.mem)
BUILT_ASM_RAMS       := $(call src_to_obj,$(ASM_FILES),$(ASM_DIRS),$(MEM_OUT_DIR),%.asm,%.ram.mem)
BUILT_ASM_FILES      := $(BUILT_ASM_ROMS) $(BUILT_ASM_RAMS)
BUILT_FIRMWARE_ROM   := $(MEM_OUT_DIR)/$(FIRMWARE_NAME).rom.mem
BUILT_FIRMWARE_RAM   := $(MEM_OUT_DIR)/$(FIRMWARE_NAME).ram.mem
BUILT_FIRMWARE_FILES := $(if $(FIRMWARE_NAME),$(BUILT_FIRMWARE_ROM) $(BUILT_FIRMWARE_RAM),)
ALL_MEM_FILES        := $(MEM_FILES) $(BUILT_ASM_FILES) $(BUILT_FIRMWARE_FILES)
OBJ_FILES := $(call src_to_obj,$(STARTUP_FILE),$(SRC_DIRS),$(FIRMWARE_OUT_DIR),%.S,%.S.o) \
             $(call src_to_obj,$(C_FILES),$(SRC_DIRS),$(FIRMWARE_OUT_DIR),%.c,%.c.o) \
             $(call src_to_obj,$(CPP_FILES),$(SRC_DIRS),$(FIRMWARE_OUT_DIR),%.cpp,%.cpp.o)

# Tool prefixes
AS      = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-as
GCC     = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-gcc
G++     = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-g++
LD      = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-ld
OBJDUMP = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-objdump
OBJCOPY = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-objcopy
READELF = $(RV32_GCC_BIN)/$(RV32_GCC_PREFIX)-readelf


# --------------
# Helper targets

.PHONY: --check_top --check_tb --check_com_port

--check_top:
	@test -n "$(TOP)" || (echo "Error: TOP module required. Usage: make <target> TOP=module_name"; exit 1)

--check_tb:
	@test -n "$(TB)" || (echo "Error: TB testbench required. Usage: make <target> TB=testbench_name"; exit 1)

--check_com_port:
	@test -n "$(COM_PORT)" || (echo "Error: COM port required. Usage: make <target> COM_PORT=com_port_name"; exit 1)


# ------------
# Main targets

.PHONY: help quick synth impl bitstream program flash sim sim_gui rtl asm firmware clean

help: ## Show this help screen
	@awk 'BEGIN {FS = ":.*?##"; printf "\n\033[1mVivado Build System\033[0m\nUsage: make \033[36m<target>\033[0m [TOP=module_name] [TB=testbench_name] [options]\n\nTargets:\n"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } END{printf "\n"}' $(MAKEFILE_LIST)

quick: --check_top $(ALL_MEM_FILES) | $(OUT_DIR) ## Quick synthesis + implementation
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/quick.tcl,$(BUILD_DIR)) \
		-tclargs $(TOP) $(FPGA_PART) \
			"$(call relpath,$(RTL_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(ALL_MEM_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(XDC_FILES),$(BUILD_DIR))"

synth: $(SYNTH_DCP) ## Run synthesis only
impl: $(ROUTE_DCP) ## Run full implementation

bitstream: --check_top $(ROUTE_DCP) | $(OUT_DIR) ## Generate bitstream
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/bitstream.tcl,$(BUILD_DIR)) \
		-tclargs $(TOP)

program: --check_top ## Program FPGA (needs bitstream first)
	@test -f $(BUILD_DIR)/out/$(TOP).bit || (echo "Error: Bitstream not found. Run 'make bitstream TOP=$(TOP)' first"; exit 1)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/program.tcl,$(BUILD_DIR)) \
		-tclargs out/$(TOP).bit

flash: --check_com_port ## Flash firmware over COM port
	python3 $(SCRIPTS_DIR)/flash.py -d $(BUILT_FIRMWARE_RAM) $(BUILT_FIRMWARE_ROM) $(COM_PORT)

sim: --check_tb $(ALL_MEM_FILES) | $(BUILD_DIR) ## Run batch simulation
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/sim.tcl,$(BUILD_DIR)) \
		-tclargs $(TB) $(FPGA_PART) \
			"$(call relpath,$(RTL_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(ALL_MEM_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(TB_FILES),$(BUILD_DIR))"

sim_gui: --check_tb $(ALL_MEM_FILES) | $(BUILD_DIR) ## Run GUI simulation
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(call relpath,$(TCL_DIR)/sim.tcl,$(BUILD_DIR)) \
		-tclargs $(TB) $(FPGA_PART) \
			"$(call relpath,$(RTL_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(ALL_MEM_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(TB_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(XSIM_WCFG),$(BUILD_DIR))"

rtl: --check_top $(ALL_MEM_FILES) | $(OUT_DIR) ## Open RTL viewer
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode gui \
		-source $(call relpath,$(TCL_DIR)/rtl.tcl,$(BUILD_DIR)) \
		-tclargs $(TOP) $(FPGA_PART) \
			"$(call relpath,$(RTL_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(ALL_MEM_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(XDC_FILES),$(BUILD_DIR))"

asm: $(BUILT_ASM_FILES) ## Build assembly files to .mem

firmware: $(BUILT_FIRMWARE_FILES) ## Build C/C++ firmware

clean: ## Remove build directory
	rm -rf $(BUILD_DIR)


# ----------------------------
# Vivado explicit flow targets (super slow)

# Implementation Stages
$(SYNTH_DCP): --check_top $(RTL_FILES) $(MEM_FILES) $(ALL_MEM_FILES) $(XDC_FILES) | $(OUT_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/synth.tcl,$(BUILD_DIR)) \
		-tclargs $(TOP) $(FPGA_PART) \
			"$(call relpath,$(RTL_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(ALL_MEM_FILES),$(BUILD_DIR))" \
			"$(call relpath,$(XDC_FILES),$(BUILD_DIR))"

$(PLACE_DCP): $(SYNTH_DCP) | $(OUT_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/place.tcl,$(BUILD_DIR))

$(ROUTE_DCP): $(PLACE_DCP) | $(OUT_DIR)
	cd $(BUILD_DIR) && $(VIVADO_BIN)/vivado -mode batch -notrace \
		-source $(call relpath,$(TCL_DIR)/route.tcl,$(BUILD_DIR))


# ----------------------
# Software build targets

# Object files to ELF
$(ASM_OUT_DIR)/%.elf: $(BUILD_DIR)/%.o | $(BUILD_DIR)
	@mkdir -p $(dir $@)
	$(LD) -T $(TCL_DIR)/rv32g_harvard.ld -o $@ $<
	$(OBJDUMP) -D $@ > $(BUILD_DIR)/$*.dis
	$(READELF) -l $@ > $(BUILD_DIR)/$*.segments.txt
	$(READELF) -S $@ > $(BUILD_DIR)/$*.sections.txt
	$(READELF) -s $@ > $(BUILD_DIR)/$*.symbols.txt

# ELF to binary files
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary $< $@

$(BUILD_DIR)/%.rom.bin: $(BUILD_DIR)/%.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary -j .text $< $@

$(BUILD_DIR)/%.ram.bin: $(BUILD_DIR)/%.elf
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O binary -j .data -j .bss $< $@


# ------------
# Source paths

vpath %.asm $(ASM_DIRS)
vpath %.c %.cpp %.S $(SRC_DIRS)


# ----------------
# Assembly targets

# Assembly to Object files
$(ASM_OUT_DIR)/%.o: %.asm | $(ASM_OUT_DIR)
	@mkdir -p $(dir $@)
	$(AS) -march=rv32i -o $@ $<

# Binary to memory files with endian conversion
$(MEM_OUT_DIR)/%.mem: $(ASM_OUT_DIR)/%.bin | $(MEM_OUT_DIR)
	@mkdir -p $(dir $@)
	xxd -p -c 4 $< | awk '{print substr($$0,7,2) substr($$0,5,2) substr($$0,3,2) substr($$0,1,2)}' > $@


# ----------------------
# Firmware (C++) targets

$(FIRMWARE_OUT_DIR)/%.elf: $(OBJ_FILES) | $(FIRMWARE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(LD) -T $(TCL_DIR)/rv32g_harvard.ld -o $@ $(OBJ_FILES)
	$(OBJDUMP) -D $@ > $(FIRMWARE_OUT_DIR)/$*.dis
	$(READELF) -l $@ > $(FIRMWARE_OUT_DIR)/$*.segments.txt
	$(READELF) -S $@ > $(FIRMWARE_OUT_DIR)/$*.sections.txt
	$(READELF) -s $@ > $(FIRMWARE_OUT_DIR)/$*.symbols.txt

$(FIRMWARE_OUT_DIR)/%.S.o: $(STARTUP_FILE) | $(FIRMWARE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(GCC) $(CFLAGS) -c -o $@ $<

$(FIRMWARE_OUT_DIR)/%.c.o: %.c | $(FIRMWARE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(GCC) $(CFLAGS) $(INC_FLAGS) -c -o $@ $<

$(FIRMWARE_OUT_DIR)/%.cpp.o: %.cpp | $(FIRMWARE_OUT_DIR)
	@mkdir -p $(dir $@)
	$(GCC) $(CXXFLAGS) $(INC_FLAGS) -c -o $@ $<

$(MEM_OUT_DIR)/%.rom.mem: $(FIRMWARE_OUT_DIR)/%.elf | $(MEM_OUT_DIR)
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O verilog -j .text $< $@

$(MEM_OUT_DIR)/%.ram.mem: $(FIRMWARE_OUT_DIR)/%.elf | $(MEM_OUT_DIR)
	@mkdir -p $(dir $@)
	$(OBJCOPY) -O verilog -j .data -j .bss $< $@


# ---------
# Utilities

# Directory creation rules
$(FIRMWARE_OUT_DIR) $(MEM_OUT_DIR) $(ASM_OUT_DIR) $(OUT_DIR) $(BUILD_DIR):
	mkdir -p $@
