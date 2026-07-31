package ibex_uvm_pkg;
  timeunit 1ns;
  timeprecision 1ps;

  import uvm_pkg::*;
  `include "uvm_macros.svh"
  `include "ibex_spike_dpi.svh"

  `uvm_analysis_imp_decl(_dmem)
  `uvm_analysis_imp_decl(_rvfi)
  `uvm_analysis_imp_decl(_ctrl)
  `uvm_analysis_imp_decl(_cov_dmem)
  `uvm_analysis_imp_decl(_cov_imem)
  `uvm_analysis_imp_decl(_cov_rvfi)
  `uvm_analysis_imp_decl(_cov_irq)
  `uvm_analysis_imp_decl(_cov_ctrl)

  `include "ibex_mem_agent.sv"
  `include "ibex_ctrl_agent.sv"
  `include "ibex_irq_agent.sv"
  `include "ibex_rvfi_agent.sv"
  `include "ibex_env.sv"
  `include "ibex_tests.sv"
endpackage
