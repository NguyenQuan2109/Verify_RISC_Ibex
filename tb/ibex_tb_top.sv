module ibex_tb_top;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  import ibex_pkg::*;
  import ibex_uvm_pkg::*;

  parameter bit RV32E = 1'b0;
  parameter rv32m_e RV32M = RV32MFast;
  parameter rv32b_e RV32B = RV32BNone;
  parameter rv32zc_e RV32ZC = RV32Zca;
  parameter regfile_e RegFile = RegFileFF;
  parameter bit BranchTargetALU = 1'b0;
  parameter bit WritebackStage = 1'b0;
  parameter bit ICache = 1'b0;
  parameter bit ICacheECC = 1'b0;
  parameter bit BranchPredictor = 1'b0;
  parameter bit DbgTriggerEn = 1'b0;
  parameter bit SecureIbex = 1'b0;
  parameter bit PMPEnable = 1'b0;
  parameter int unsigned PMPGranularity = 0;
  parameter int unsigned PMPNumRegions = 4;
  parameter int unsigned MHPMCounterNum = 0;
  parameter int unsigned MHPMCounterWidth = 40;
  parameter logic [31:0] BootAddr = 32'h8000_0000;
  parameter logic [31:0] DmBaseAddr = 32'h1a11_0000;
  parameter logic [31:0] DmAddrMask = 32'h0000_0fff;
  parameter logic [31:0] DmHaltAddr = 32'h8000_0000;
  parameter logic [31:0] DmExceptionAddr = 32'h8000_0008;

  logic clk = 1'b0;
  always #5ns clk = ~clk;

  ibex_mem_if imem_if(clk);
  ibex_mem_if dmem_if(clk);
  ibex_ctrl_if #(
    .SCRAMBLE_KEY_W(ibex_pkg::SCRAMBLE_KEY_W),
    .SCRAMBLE_NONCE_W(ibex_pkg::SCRAMBLE_NONCE_W)
  ) ctrl_if(clk);
  ibex_irq_if irq_if(clk);
  ibex_rvfi_if rvfi_if(clk);

  assign imem_if.rst_n = ctrl_if.rst_n;
  assign dmem_if.rst_n = ctrl_if.rst_n;
  assign irq_if.rst_n = ctrl_if.rst_n;
  assign rvfi_if.rst_n = ctrl_if.rst_n;
  assign imem_if.we = 1'b0;
  assign imem_if.be = '0;
  assign imem_if.wdata = '0;
  assign imem_if.wintg = '0;
  assign imem_if.misaligned_first = 1'b0;
  assign imem_if.misaligned_second = 1'b0;
  assign imem_if.misaligned_first_saw_error = 1'b0;
  assign imem_if.m_mode_access = 1'b1;

  ibex_top_tracing #(
    .PMPEnable(PMPEnable),
    .PMPGranularity(PMPGranularity),
    .PMPNumRegions(PMPNumRegions),
    .MHPMCounterNum(MHPMCounterNum),
    .MHPMCounterWidth(MHPMCounterWidth),
    .RV32E(RV32E),
    .RV32M(RV32M),
    .RV32B(RV32B),
    .RV32ZC(RV32ZC),
    .RegFile(RegFile),
    .BranchTargetALU(BranchTargetALU),
    .WritebackStage(WritebackStage),
    .ICache(ICache),
    .ICacheECC(ICacheECC),
    .BranchPredictor(BranchPredictor),
    .DbgTriggerEn(DbgTriggerEn),
    .SecureIbex(SecureIbex),
    .DmBaseAddr(DmBaseAddr),
    .DmAddrMask(DmAddrMask),
    .DmHaltAddr(DmHaltAddr),
    .DmExceptionAddr(DmExceptionAddr)
  ) dut (
    .clk_i(clk),
    .rst_ni(ctrl_if.rst_n),
    .test_en_i(1'b0),
    .scan_rst_ni(1'b1),
    .ram_cfg_icache_tag_i('0),
    .ram_cfg_rsp_icache_tag_o(),
    .ram_cfg_icache_data_i('0),
    .ram_cfg_rsp_icache_data_o(),
    .hart_id_i(32'b0),
    .boot_addr_i(BootAddr),
    .instr_req_o(imem_if.req),
    .instr_gnt_i(imem_if.gnt),
    .instr_rvalid_i(imem_if.rvalid),
    .instr_addr_o(imem_if.addr),
    .instr_rdata_i(imem_if.rdata),
    .instr_rdata_intg_i(imem_if.rintg),
    .instr_err_i(imem_if.error),
    .data_req_o(dmem_if.req),
    .data_gnt_i(dmem_if.gnt),
    .data_rvalid_i(dmem_if.rvalid),
    .data_we_o(dmem_if.we),
    .data_be_o(dmem_if.be),
    .data_addr_o(dmem_if.addr),
    .data_wdata_o(dmem_if.wdata),
    .data_wdata_intg_o(dmem_if.wintg),
    .data_rdata_i(dmem_if.rdata),
    .data_rdata_intg_i(dmem_if.rintg),
    .data_err_i(dmem_if.error),
    .irq_software_i(irq_if.irq_software),
    .irq_timer_i(irq_if.irq_timer),
    .irq_external_i(irq_if.irq_external),
    .irq_fast_i(irq_if.irq_fast),
    .irq_nm_i(irq_if.irq_nm),
    .scramble_key_valid_i(ctrl_if.scramble_key_valid),
    .scramble_key_i(ctrl_if.scramble_key),
    .scramble_nonce_i(ctrl_if.scramble_nonce),
    .scramble_req_o(ctrl_if.scramble_req),
    .debug_req_i(ctrl_if.debug_req),
    .crash_dump_o(),
    .double_fault_seen_o(),
    .fetch_enable_i(ctrl_if.fetch_enable),
    .mcounteren_writable_i(ctrl_if.mcounteren_writable),
    .alert_minor_o(),
    .alert_major_internal_o(),
    .alert_major_bus_o(),
    .core_sleep_o(),
    .lockstep_cmp_en_o(),
    .data_req_shadow_o(),
    .data_we_shadow_o(),
    .data_be_shadow_o(),
    .data_addr_shadow_o(),
    .data_wdata_shadow_o(),
    .data_wdata_intg_shadow_o(),
    .instr_req_shadow_o(),
    .instr_addr_shadow_o()
  );

  assign rvfi_if.valid = dut.rvfi_valid;
  assign rvfi_if.order = dut.rvfi_order;
  assign rvfi_if.insn = dut.rvfi_insn;
  assign rvfi_if.trap = dut.rvfi_trap;
  assign rvfi_if.halt = dut.rvfi_halt;
  assign rvfi_if.intr = dut.rvfi_intr;
  assign rvfi_if.mode = dut.rvfi_mode;
  assign rvfi_if.ixl = dut.rvfi_ixl;
  assign rvfi_if.rs1_addr = dut.rvfi_rs1_addr;
  assign rvfi_if.rs2_addr = dut.rvfi_rs2_addr;
  assign rvfi_if.rs3_addr = dut.rvfi_rs3_addr;
  assign rvfi_if.rs1_rdata = dut.rvfi_rs1_rdata;
  assign rvfi_if.rs2_rdata = dut.rvfi_rs2_rdata;
  assign rvfi_if.rs3_rdata = dut.rvfi_rs3_rdata;
  assign rvfi_if.rd_addr = dut.rvfi_rd_addr;
  assign rvfi_if.rd_wdata = dut.rvfi_rd_wdata;
  assign rvfi_if.pc_rdata = dut.rvfi_pc_rdata;
  assign rvfi_if.pc_wdata = dut.rvfi_pc_wdata;
  assign rvfi_if.mem_addr = dut.rvfi_mem_addr;
  assign rvfi_if.mem_rmask = dut.rvfi_mem_rmask;
  assign rvfi_if.mem_wmask = dut.rvfi_mem_wmask;
  assign rvfi_if.mem_rdata = dut.rvfi_mem_rdata;
  assign rvfi_if.mem_wdata = dut.rvfi_mem_wdata;
  assign rvfi_if.ext_pre_mip = dut.rvfi_ext_pre_mip;
  assign rvfi_if.ext_post_mip = dut.rvfi_ext_post_mip;
  assign rvfi_if.ext_nmi = dut.rvfi_ext_nmi;
  assign rvfi_if.ext_nmi_int = dut.rvfi_ext_nmi_int;
  assign rvfi_if.ext_debug_req = dut.rvfi_ext_debug_req;
  assign rvfi_if.ext_debug_mode = dut.rvfi_ext_debug_mode;
  assign rvfi_if.ext_rf_wr_suppress = dut.rvfi_ext_rf_wr_suppress;
  assign rvfi_if.ext_mcycle = dut.rvfi_ext_mcycle;
  assign rvfi_if.ext_mhpmcounters = dut.rvfi_ext_mhpmcounters;
  assign rvfi_if.ext_mhpmcountersh = dut.rvfi_ext_mhpmcountersh;
  assign rvfi_if.ext_ic_scr_key_valid = dut.rvfi_ext_ic_scr_key_valid;
  assign rvfi_if.ext_irq_valid = dut.rvfi_ext_irq_valid;

  // Metadata not present on Ibex's external bus is observed at the LSU boundary.
  assign dmem_if.misaligned_first =
    dut.u_ibex_top.u_ibex_core.load_store_unit_i.handle_misaligned_d |
    ((dut.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_type_i == 2'b01) &
     (dut.u_ibex_top.u_ibex_core.load_store_unit_i.data_offset == 2'b01));
  assign dmem_if.misaligned_second =
    dut.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o;
  assign dmem_if.misaligned_first_saw_error =
    dut.u_ibex_top.u_ibex_core.load_store_unit_i.addr_incr_req_o &
    dut.u_ibex_top.u_ibex_core.load_store_unit_i.lsu_err_d;
  assign dmem_if.m_mode_access =
    dut.u_ibex_top.u_ibex_core.priv_mode_lsu == ibex_pkg::PRIV_LVL_M;

  initial begin
    uvm_config_db#(virtual ibex_mem_if)::set(null, "*", "imem_vif", imem_if);
    uvm_config_db#(virtual ibex_mem_if)::set(null, "*", "dmem_vif", dmem_if);
    uvm_config_db#(virtual ibex_ctrl_if)::set(null, "*", "ctrl_vif", ctrl_if);
    uvm_config_db#(virtual ibex_irq_if)::set(null, "*", "irq_vif", irq_if);
    uvm_config_db#(virtual ibex_rvfi_if)::set(null, "*", "rvfi_vif", rvfi_if);
    run_test();
  end
endmodule
