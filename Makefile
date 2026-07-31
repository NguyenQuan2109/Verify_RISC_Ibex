# ==============================================================================
# Ibex UVM + Spike cosimulation build
# ==============================================================================

# Project paths
ROOT             := $(abspath .)
BUILD            := $(ROOT)/build
FW_BUILD         := $(BUILD)/firmware
DPI_BUILD        := $(BUILD)/dpi
LOG_BUILD        := $(BUILD)/logs
COV_BUILD        := $(BUILD)/coverage
RVDV_BUILD       := $(BUILD)/riscv_dv

# Questa / UVM installation
QUESTA_ROOT      ?= /home/nguyenquan/RISCV/questasim
QUESTA_UVM_LIB   ?= $(QUESTA_ROOT)/uvm-1.2
QUESTA_UVM_SRC   ?= $(QUESTA_ROOT)/verilog_src/uvm-1.2/src
QUESTA_INC       ?= $(QUESTA_ROOT)/include

# RISC-V toolchain and Spike cosimulation installation
RISCV_GCC        ?= /usr/bin/riscv64-unknown-elf-gcc
RISCV_OBJCOPY    ?= /usr/bin/riscv64-unknown-elf-objcopy
CXX              ?= g++
SPIKE_BIN        ?= /opt/spike-cosim/bin/spike
PKG_CONFIG_PATH  ?= /opt/spike-cosim/lib/pkgconfig
SPIKE_PC_LIBS    := riscv-riscv riscv-disasm riscv-fesvr

# Vendored RISC-V DV generator
RVDV_ROOT        := $(ROOT)/third_party/riscv-dv
RVDV_PYTHON      ?= python3
RVDV_TEST        ?= riscv_machine_mode_rand_test
RVDV_ISA         ?= rv32imc_zicsr_zifencei
RVDV_MABI        ?= ilp32
RVDV_OUT         := $(RVDV_BUILD)/$(RVDV_TEST)_$(SEED)
RVDV_RUN         := $(RVDV_OUT)/run
RVDV_BIN         := $(RVDV_RUN)/asm_test/$(RVDV_TEST)_0.bin
RVDV_SIM_TEST    := random_$(RVDV_TEST)
RVDV_GCC_OPTS    := -mno-strict-align -Wl,--no-relax -T$(ROOT)/testlist/link.ld
RVDV_SIM_OPTS    := +uvm_set_inst_override=riscv_asm_program_gen,ibex_asm_program_gen,uvm_test_top.asm_gen \
                    +require_signature_addr=1 +signature_addr=8ffffffc \
                    +pmp_num_regions=0 +pmp_granularity=0 +tvec_alignment=8

# Simulation selection
TEST             ?= ibex_smoke_test
UVM_TEST         ?= $(TEST)
SEED             ?= 1
GUI              ?= 0
ASM              ?= testlist/directed_test/smoke.S
PROGRAM          ?= $(basename $(notdir $(ASM)))
ELF              ?= $(FW_BUILD)/$(PROGRAM).elf
BIN              ?= $(FW_BUILD)/$(PROGRAM).bin
LOG              ?= $(LOG_BUILD)/$(TEST)_$(SEED).log
COV_DB           := $(COV_BUILD)/$(TEST)_$(SEED).ucdb
GUI_DO           := $(ROOT)/scripts/ibex_gui.do

export PRJ_DIR   := $(ROOT)
export PKG_CONFIG_PATH

# Compile options
VLOG_FLAGS       := -64 -work work -L mtiUvm -sv -mfcu +cover=bcesft         \
                    -cuname ibex_uvm_cu                                      \
                    +define+RVFI +define+UVM +define+UVM_REGEX_NO_DPI        \
                    +incdir+$(QUESTA_UVM_SRC)                                \
                    -suppress 2583,13314,13361 -timescale 1ns/1ps

DPI_CXXFLAGS     := -std=c++17 -fPIC -O2                                     \
                    -I$(QUESTA_INC) -I$(ROOT)/cosim

.PHONY: help check-tools check-riscv-dv firmware dpi compile run \
        test smoke riscv-dv-gen random clean

# ==============================================================================
# User targets
# ==============================================================================

help:
	@echo "Ibex UVM + Spike co-simulation"
	@echo ""
	@echo "Main targets:"
	@echo "  make smoke        Build and run the directed smoke test."
	@echo "  make test         Build ASM=<file.S>, then run UVM_TEST=<test>."
	@echo "  make random       Generate one RISC-V DV program and run it in UVM."
	@echo "  make riscv-dv-gen Generate a RISC-V DV binary only; do not run the DUT."
	@echo "  make compile      Compile RTL, UVM TB, assertions, and Spike DPI."
	@echo "  make run          Run an existing binary: BIN=<file.bin>."
	@echo "  make clean        Remove build products."
	@echo ""
	@echo "Frequently used variables:"
	@echo "  ASM=<file.S>          Directed assembly source (default: $(ASM))"
	@echo "  TEST=<uvm_test>       Log/test label used by make run"
	@echo "  UVM_TEST=<uvm_test>   UVM test class (default: $(UVM_TEST))"
	@echo "  BIN=<file.bin>        Raw program binary loaded through +bin=<path>"
	@echo "  RVDV_TEST=<name>      Test name from testlist/testlist.yaml"
	@echo "  SEED=<n>              Random seed (default: $(SEED))"
	@echo "  GUI=1                 Open the final UVM simulation in Questa GUI"
	@echo ""
	@echo "Examples:"
	@echo "  make smoke"
	@echo "  make test ASM=testlist/directed_test/smoke.S TEST=ibex_smoke_test"
	@echo "  make random SEED=123"
	@echo "  make random RVDV_TEST=riscv_arithmetic_basic_test SEED=42"
	@echo "  make run UVM_TEST=ibex_base_test BIN=build/riscv_dv/.../program.bin"
	@echo "  make smoke GUI=1"
	@echo "  make random GUI=1 SEED=123"

test: firmware run

smoke: test

# ==============================================================================
# Environment checks
# ==============================================================================

check-tools:
	@test -x "$(RISCV_GCC)"
	@test -x "$(RISCV_OBJCOPY)"
	@command -v vlog >/dev/null
	@command -v vsim >/dev/null
	@test -d "$(QUESTA_UVM_LIB)"
	@test -d "$(QUESTA_UVM_SRC)"
	@test -f "$(QUESTA_INC)/svdpi.h"
	@test -x "$(SPIKE_BIN)"
	@pkg-config --exists $(SPIKE_PC_LIBS)

check-riscv-dv:
	@test -f "$(RVDV_ROOT)/run.py"
	@test -f "$(RVDV_ROOT)/files.f"
	@test -f "$(RVDV_ROOT)/yaml/simulator.yaml"
	@test -f "$(RVDV_ROOT)/scripts/link.ld"
	@test -f "$(RVDV_ROOT)/src/riscv_instr_pkg.sv"
	@test -f "$(RVDV_ROOT)/test/riscv_instr_base_test.sv"
	@$(RVDV_PYTHON) -c "import yaml"

# ==============================================================================
# Parameterized directed firmware build
# ==============================================================================

$(ELF): $(ASM) testlist/link.ld
	@mkdir -p $(@D)
	$(RISCV_GCC) -march=rv32imc -mabi=ilp32 -nostdlib -nostartfiles \
	  -Wl,--no-relax -T testlist/link.ld -o $@ $<

$(BIN): $(ELF)
	$(RISCV_OBJCOPY) -O binary $< $@

firmware: $(BIN)

# ==============================================================================
# RISC-V DV random-program generation
# ==============================================================================

# Generate one assembly program and compile it into a raw binary. The target
# configuration and Ibex-specific factory extension both live in this project.
riscv-dv-gen: check-tools check-riscv-dv
	@mkdir -p $(RVDV_OUT)
	cd $(RVDV_OUT) && \
	  QUESTA_HOME="$(QUESTA_ROOT)" \
	  RISCV_DV_ROOT="$(RVDV_ROOT)" \
	  RISCV_GCC="$(RISCV_GCC)" \
	  RISCV_OBJCOPY="$(RISCV_OBJCOPY)" \
	  $(RVDV_PYTHON) "$(RVDV_ROOT)/run.py" \
	    --testlist "$(ROOT)/testlist/testlist.yaml" \
	    --custom_target "$(ROOT)/riscv_dv_extension" \
	    --user_extension_dir "$(ROOT)/riscv_dv_extension" \
	    --csr_yaml "$(ROOT)/riscv_dv_extension/csr_description.yaml" \
	    --simulator questa \
	    --isa "$(RVDV_ISA)" \
	    --mabi "$(RVDV_MABI)" \
	    --test "$(RVDV_TEST)" \
	    --seed "$(SEED)" \
	    --iterations 1 \
	    --steps gen,gcc_compile \
	    --output "$(RVDV_RUN)" \
	    --end_signature_addr 8ffffffc \
	    --gcc_opts='$(RVDV_GCC_OPTS)' \
	    --sim_opts='$(RVDV_SIM_OPTS)'
	@test -f "$(RVDV_BIN)"

# Generate the selected RISC-V DV program, then load its binary into the UVM
# memory model through the existing +bin=<path> plusarg.
random: riscv-dv-gen
	$(MAKE) --no-print-directory run \
	  TEST=$(RVDV_SIM_TEST) \
	  UVM_TEST=ibex_base_test \
	  SEED=$(SEED) \
	  GUI=$(GUI) \
	  BIN=$(RVDV_BIN)

# ==============================================================================
# Spike DPI shared library
# ==============================================================================

$(DPI_BUILD)/libibex_spike.so: tb/dpi/ibex_spike_dpi.cc \
                                  cosim/cosim_dpi.cc          \
                                  cosim/spike_cosim.cc
	@mkdir -p $(@D)
	$(CXX) $(DPI_CXXFLAGS) $$(pkg-config --cflags $(SPIKE_PC_LIBS)) \
	  -c tb/dpi/ibex_spike_dpi.cc -o $(DPI_BUILD)/ibex_spike_dpi.o
	$(CXX) $(DPI_CXXFLAGS) $$(pkg-config --cflags $(SPIKE_PC_LIBS)) \
	  -c cosim/cosim_dpi.cc -o $(DPI_BUILD)/cosim_dpi.o
	$(CXX) $(DPI_CXXFLAGS) $$(pkg-config --cflags $(SPIKE_PC_LIBS)) \
	  -c cosim/spike_cosim.cc -o $(DPI_BUILD)/spike_cosim.o
	$(CXX) -shared -static-libstdc++ -static-libgcc -o $@ \
	  $(DPI_BUILD)/ibex_spike_dpi.o \
	  $(DPI_BUILD)/cosim_dpi.o \
	  $(DPI_BUILD)/spike_cosim.o \
	  $$(pkg-config --libs $(SPIKE_PC_LIBS))

dpi: $(DPI_BUILD)/libibex_spike.so

# ==============================================================================
# Questa compilation and simulation
# ==============================================================================

compile: check-tools dpi filelist/rtl.f filelist/tb.f
	@mkdir -p $(BUILD)
	@cd $(BUILD) && vmap -c >/dev/null
	@cd $(BUILD) && test -d work || vlib work
	@cd $(BUILD) && vmap mtiUvm $(QUESTA_UVM_LIB) >/dev/null
	cd $(BUILD) && vlog $(VLOG_FLAGS) \
	  -f $(ROOT)/filelist/rtl.f \
	  -f $(ROOT)/filelist/tb.f \
	  -l $(BUILD)/compile.log

run: compile
	@if [ "$(GUI)" = "1" ]; then \
	  $(MAKE) --no-print-directory gui-run \
	    TEST=$(TEST) UVM_TEST=$(UVM_TEST) SEED=$(SEED) BIN=$(BIN); \
	else \
	  $(MAKE) --no-print-directory batch-run \
	    TEST=$(TEST) UVM_TEST=$(UVM_TEST) SEED=$(SEED) BIN=$(BIN); \
	fi

.PHONY: batch-run gui-run

batch-run:
	@mkdir -p $(dir $(LOG))
	cd $(BUILD) && vsim -64 -c -modelsimini modelsim.ini -L mtiUvm \
	  -dpicpppath /usr/bin/gcc -suppress 13408 \
	  -sv_lib $(DPI_BUILD)/libibex_spike \
	  work.ibex_tb_top \
	  -sv_seed $(SEED) \
	  +UVM_TESTNAME=$(UVM_TEST) \
	  +UVM_VERBOSITY=UVM_LOW \
	  +bin=$(abspath $(BIN)) \
	  +cosim_log=$(BUILD)/spike_$(TEST)_$(SEED).log \
	  -l $(abspath $(LOG)) \
	  -do "run -all; quit -f"
	@! grep -Eq "UVM_(FATAL|ERROR) *: *[1-9]|\*\* (Error|Fatal):" $(LOG)

# The GUI deliberately does not issue "run -all": select signals in Objects,
# add them to Wave, then run the simulation manually.
gui-run: $(GUI_DO)
	@mkdir -p $(dir $(LOG)) $(COV_BUILD)
	cd $(BUILD) && vsim -64 -modelsimini modelsim.ini -L mtiUvm \
	  -coverage -assertdebug -dpicpppath /usr/bin/gcc -suppress 13408 \
	  -sv_lib $(DPI_BUILD)/libibex_spike \
	  work.ibex_tb_top \
	  -sv_seed $(SEED) \
	  +UVM_TESTNAME=$(UVM_TEST) \
	  +UVM_VERBOSITY=UVM_LOW \
	  +bin=$(abspath $(BIN)) \
	  +cosim_log=$(BUILD)/spike_$(TEST)_$(SEED).log \
	  -l $(abspath $(LOG)) \
	  -do "set ibex_cov_db_arg {$(abspath $(COV_DB))}; do $(GUI_DO)"

# ==============================================================================
# Cleanup
# ==============================================================================

clean:
	rm -rf $(BUILD)
