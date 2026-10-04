# =============================================================================
#  Makefile — 2D Mesh Network-on-Chip (NoC) Build & Verification Suite
# =============================================================================

RTL_DIR = rtl
DV_DIR  = dv
SIM_DIR = sim

IVERILOG = iverilog -g2012
VVP      = vvp
GTKWAVE  = gtkwave

.PHONY: all clean help router directed 16x16 single backpressure random large 5x5

all: router directed 16x16 single backpressure random large 5x5
	@echo "======================================================================"
	@echo " ALL TESTBENCHES EXECUTED CLEANLY!"
	@echo "======================================================================"

router:
	@echo "--- Compiling and Running tb_router ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_router.vvp $(DV_DIR)/tb_router.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_router.vvp

directed:
	@echo "--- Compiling and Running tb_mesh_directed ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_directed.vvp $(DV_DIR)/tb_mesh_directed.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_directed.vvp

16x16:
	@echo "--- Compiling and Running tb_mesh_directed_16x16 ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_directed_16x16.vvp $(DV_DIR)/tb_mesh_directed_16x16.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_directed_16x16.vvp

single:
	@echo "--- Compiling and Running tb_mesh_single ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_single.vvp $(DV_DIR)/tb_mesh_single.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_single.vvp

backpressure:
	@echo "--- Compiling and Running tb_mesh_backpressure ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_backpressure.vvp $(DV_DIR)/tb_mesh_backpressure.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_backpressure.vvp

random:
	@echo "--- Compiling and Running tb_mesh_random ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_random.vvp $(DV_DIR)/tb_mesh_random.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_random.vvp

large:
	@echo "--- Compiling and Running tb_mesh_large (20,000 packets) ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_large.vvp $(DV_DIR)/tb_mesh_large.sv $(RTL_DIR)/mesh_4x4.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_large.vvp

5x5:
	@echo "--- Compiling and Running tb_mesh_5x5 ---"
	$(IVERILOG) -o $(SIM_DIR)/tb_mesh_5x5.vvp $(DV_DIR)/tb_mesh_5x5.sv $(RTL_DIR)/mesh_5x5.sv $(RTL_DIR)/mesh_router_5x5.sv
	$(VVP) $(SIM_DIR)/tb_mesh_5x5.vvp

clean:
	@echo "--- Cleaning build artifacts ---"
	rm -f $(SIM_DIR)/*.vvp $(SIM_DIR)/*.log *.vcd *.vvp *.log

help:
	@echo "Usage: make [target]"
	@echo "Targets:"
	@echo "  all          Run all testbenches"
	@echo "  5x5          Run 5x5 Mesh top-level testbench"
	@echo "  large        Run 20,000 packet large stress testbench"
	@echo "  router       Run 5-port single router unit testbench"
	@echo "  directed     Run basic directed testbench"
	@echo "  16x16        Run exhaustive 256-pair testbench"
	@echo "  clean        Remove compiled binaries and waveform logs"
