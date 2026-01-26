ROOT_DIR     := $(shell dirname $(realpath $(lastword $(MAKEFILE_LIST))))

# Project details
# RISC-V IP Core
CORE         := rv32i
IP_NAME      := risc_v_32i_cm
IP_VENDOR    := ISAE
IP_LIBRARY   := user
IP_VERSION   := 1.0

# Hardware information
TARGET_PART  := xc7z020clg400-1
BOARD_PART   := digilentinc.com:zybo-z7-20:part0:1.2

# Vivado (PL layer)
PROJECT_NAME := RISC_V_worker_PL_layer
HW           := riscv_worker_hardware.xsa

# Vitis (PS layer)
WORKSPACE    := vitis_ws
PLATFORM     := RISC_V_worker_PS_layer_platform
CPU          := ps7_cortexa9_0
APPLICATION  := RISC_V_worker_PS_application
CODE         := zynq
VERBOSITY    := 1

# Relevant directories
SCRIPTS_DIR  := scripts
CORE_DIR     := $(ROOT_DIR)/../cores/$(CORE)

.PHONY: riscv_ip riscv_worker_pl riscv_worker_ps all clean_riscv_ip clean_riscv_worker_pl clean_riscv_worker_ps clean

# Building RISC-V IP Core
riscv_ip:
	@echo "Creating RISC-V IP Core from: $(CORE_DIR)"
	@vivado -mode batch -source $(SCRIPTS_DIR)/package_riscv_ip.tcl \
			-tclargs $(IP_NAME) $(IP_VENDOR) $(IP_LIBRARY) $(IP_VERSION) $(TARGET_PART) $(CORE)

riscv_worker_pl: riscv_ip
	@echo "Creating RISC-V worker for: "
	@echo "Target: $(TARGTE_PART)"
	@echo "From RISC-V IP Core: $(CORE)"
	@vivado -mode batch -source $(SCRIPTS_DIR)/build_riscv_worker_pl.tcl \
			-tclargs $(PROJECT_NAME) $(TARGET_PART) $(BOARD_PART) $(HW)

riscv_worker_ps:
	@echo "Creating RISC-V worker PS layer for: "
	@echo "CPU: $(CPU)"
	@echo "Based on XSA: $(ROOT_DIR)/$(HW)"
	@echo "$(PLATFORM) saved in $(ROOT_DIR)/$(WORKSPACE)"
	@echo "Used source code: $(ROOT_DIR)/$(CODE)"
	@vitis -s $(SCRIPTS_DIR)/build_riscv_worker_ps_pl.py   \
			  --workspace "$(WORKSPACE)"                   \
			  --platform  "$(PLATFORM)"                    \
			  --hw_design "$(HW)"                          \
			  --cpu       "$(CPU)"                         \
			  --code      "$(CODE)"                        \
			  --verbose   $(VERBOSITY)

all: riscv_worker_pl riscv_worker_ps:

clean_riscv_ip:
	@echo "Removing ip_repos/..."
	@rm -rf ip_repos/

clean_riscv_worker_pl:
	@echo "Removing build_riscv_worker_pl"
	@rm -rf build_riscv_worker_pl/

clean_riscv_worker_ps:
	@echo "Removing $(WORKSPACE)/"
	@rm -rf $(WORKSPACE)/

clean: clean_riscv_ip clean_riscv_worker_pl clean_riscv_worker_ps
