// Merged from tb/interfaces/ibex_mem_if.sv
interface ibex_mem_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  logic        rst_n;
  logic        req;
  logic        gnt;
  logic [31:0] addr;
  logic        we;
  logic [3:0]  be;
  logic [31:0] wdata;
  logic [6:0]  wintg;
  logic        rvalid;
  logic [31:0] rdata;
  logic [6:0]  rintg;
  logic        error;

  // Ibex-specific metadata required by the Spike data-access checker.
  logic misaligned_first;
  logic misaligned_second;
  logic misaligned_first_saw_error;
  logic m_mode_access;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    input  rst_n, req, addr, we, be, wdata, wintg;
    output gnt, rvalid, rdata, rintg, error;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n, req, gnt, addr, we, be, wdata, wintg;
    input rvalid, rdata, rintg, error;
    input misaligned_first, misaligned_second;
    input misaligned_first_saw_error, m_mode_access;
  endclocking
endinterface


// Merged from tb/interfaces/ibex_ctrl_if.sv
interface ibex_ctrl_if #(
  parameter int SCRAMBLE_KEY_W   = 128,
  parameter int SCRAMBLE_NONCE_W = 64
) (input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  logic rst_n;
  logic debug_req;
  logic [3:0] fetch_enable;
  logic [3:0] mcounteren_writable;
  logic scramble_key_valid;
  logic [SCRAMBLE_KEY_W-1:0] scramble_key;
  logic [SCRAMBLE_NONCE_W-1:0] scramble_nonce;
  logic scramble_req;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    output rst_n, debug_req, fetch_enable, mcounteren_writable;
    output scramble_key_valid, scramble_key, scramble_nonce;
    input scramble_req;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n, debug_req, fetch_enable, mcounteren_writable;
    input scramble_key_valid, scramble_key, scramble_nonce, scramble_req;
  endclocking
endinterface


// Merged from tb/interfaces/ibex_irq_if.sv
interface ibex_irq_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  logic rst_n;
  logic irq_software;
  logic irq_timer;
  logic irq_external;
  logic [14:0] irq_fast;
  logic irq_nm;

  clocking drv_cb @(posedge clk);
    default input #1step output #0;
    input rst_n;
    output irq_software, irq_timer, irq_external, irq_fast, irq_nm;
  endclocking

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n, irq_software, irq_timer, irq_external, irq_fast, irq_nm;
  endclocking
endinterface


// Merged from tb/interfaces/ibex_rvfi_if.sv
interface ibex_rvfi_if(input logic clk);
  timeunit 1ns;
  timeprecision 1ps;

  logic rst_n;
  logic valid;
  logic [63:0] order;
  logic [31:0] insn;
  logic trap;
  logic halt;
  logic intr;
  logic [1:0] mode;
  logic [1:0] ixl;
  logic [4:0] rs1_addr, rs2_addr, rs3_addr, rd_addr;
  logic [31:0] rs1_rdata, rs2_rdata, rs3_rdata, rd_wdata;
  logic [31:0] pc_rdata, pc_wdata;
  logic [31:0] mem_addr;
  logic [3:0] mem_rmask, mem_wmask;
  logic [31:0] mem_rdata, mem_wdata;
  logic [31:0] ext_pre_mip, ext_post_mip;
  logic ext_nmi, ext_nmi_int, ext_debug_req, ext_debug_mode;
  logic ext_rf_wr_suppress;
  logic [63:0] ext_mcycle;
  logic [31:0] ext_mhpmcounters [10];
  logic [31:0] ext_mhpmcountersh [10];
  logic ext_ic_scr_key_valid;
  logic ext_irq_valid;

  clocking mon_cb @(posedge clk);
    default input #1step output #0;
    input rst_n, valid, order, insn, trap, halt, intr, mode, ixl;
    input rs1_addr, rs2_addr, rs3_addr, rd_addr;
    input rs1_rdata, rs2_rdata, rs3_rdata, rd_wdata;
    input pc_rdata, pc_wdata, mem_addr, mem_rmask, mem_wmask, mem_rdata, mem_wdata;
    input ext_pre_mip, ext_post_mip, ext_nmi, ext_nmi_int;
    input ext_debug_req, ext_debug_mode, ext_rf_wr_suppress, ext_mcycle;
    input ext_mhpmcounters, ext_mhpmcountersh;
    input ext_ic_scr_key_valid, ext_irq_valid;
  endclocking
endinterface


