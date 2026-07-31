`ifndef IBEX_SPIKE_DPI_SVH
`define IBEX_SPIKE_DPI_SVH

import "DPI-C" function chandle ibex_spike_cosim_init(
  string isa_string,
  bit [31:0] start_pc,
  bit [31:0] start_mtvec,
  string log_file_path,
  bit [31:0] pmp_num_regions,
  bit [31:0] pmp_granularity,
  bit [31:0] mhpm_counter_num,
  bit secure_ibex,
  bit icache,
  bit [31:0] dm_start_addr,
  bit [31:0] dm_end_addr
);
import "DPI-C" function void ibex_spike_cosim_release(chandle cosim_handle);

import "DPI-C" function int riscv_cosim_step(chandle cosim_handle,
  bit [4:0] write_reg, bit [31:0] write_reg_data, bit [31:0] pc,
  bit sync_trap, bit suppress_reg_write);
import "DPI-C" function void riscv_cosim_set_mip(chandle cosim_handle,
  bit [31:0] pre_mip, bit [31:0] post_mip);
import "DPI-C" function void riscv_cosim_set_nmi(chandle cosim_handle, bit nmi);
import "DPI-C" function void riscv_cosim_set_nmi_int(chandle cosim_handle, bit nmi_int);
import "DPI-C" function void riscv_cosim_set_debug_req(chandle cosim_handle, bit debug_req);
import "DPI-C" function void riscv_cosim_set_mcycle(chandle cosim_handle, bit [63:0] mcycle);
import "DPI-C" function void riscv_cosim_set_csr(chandle cosim_handle,
  int csr_id, bit [31:0] csr_val);
import "DPI-C" function void riscv_cosim_set_ic_scr_key_valid(chandle cosim_handle, bit valid);
import "DPI-C" function void riscv_cosim_notify_dside_access(chandle cosim_handle,
  bit store, bit [31:0] addr, bit [31:0] data, bit [3:0] be, bit error,
  bit misaligned_first, bit misaligned_second, bit misaligned_first_saw_error,
  bit m_mode_access);
import "DPI-C" function int riscv_cosim_set_iside_error(chandle cosim_handle,
  bit [31:0] addr);
import "DPI-C" function int riscv_cosim_get_num_errors(chandle cosim_handle);
import "DPI-C" function string riscv_cosim_get_error(chandle cosim_handle, int index);
import "DPI-C" function void riscv_cosim_clear_errors(chandle cosim_handle);
import "DPI-C" function void riscv_cosim_write_mem_byte(chandle cosim_handle,
  bit [31:0] addr, bit [7:0] data);
import "DPI-C" function int unsigned riscv_cosim_get_insn_cnt(chandle cosim_handle);

`endif
