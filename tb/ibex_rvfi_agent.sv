class ibex_rvfi_item extends uvm_sequence_item;
  bit irq_only;
  bit [63:0] order;
  bit [31:0] insn;
  bit trap, halt, intr;
  bit [1:0] mode, ixl;
  bit [4:0] rs1_addr, rs2_addr, rs3_addr, rd_addr;
  bit [31:0] rs1_rdata, rs2_rdata, rs3_rdata, rd_wdata;
  bit [31:0] pc_rdata, pc_wdata;
  bit [31:0] mem_addr;
  bit [3:0] mem_rmask, mem_wmask;
  bit [31:0] mem_rdata, mem_wdata;
  bit [31:0] pre_mip, post_mip;
  bit nmi, nmi_int, debug_req, debug_mode, rf_wr_suppress;
  bit [63:0] mcycle;
  bit [31:0] mhpmcounters [10];
  bit [31:0] mhpmcountersh [10];
  bit ic_scr_key_valid;

  `uvm_object_utils_begin(ibex_rvfi_item)
    `uvm_field_int(irq_only, UVM_DEFAULT)
    `uvm_field_int(order, UVM_DEC)
    `uvm_field_int(insn, UVM_HEX)
    `uvm_field_int(trap, UVM_DEFAULT)
    `uvm_field_int(halt, UVM_DEFAULT)
    `uvm_field_int(intr, UVM_DEFAULT)
    `uvm_field_int(mode, UVM_HEX)
    `uvm_field_int(ixl, UVM_HEX)
    `uvm_field_int(rd_addr, UVM_DEC)
    `uvm_field_int(rd_wdata, UVM_HEX)
    `uvm_field_int(pc_rdata, UVM_HEX)
    `uvm_field_int(pc_wdata, UVM_HEX)
    `uvm_field_int(mem_addr, UVM_HEX)
    `uvm_field_int(mem_rmask, UVM_HEX)
    `uvm_field_int(mem_wmask, UVM_HEX)
    `uvm_field_int(mem_rdata, UVM_HEX)
    `uvm_field_int(mem_wdata, UVM_HEX)
    `uvm_field_int(pre_mip, UVM_HEX)
    `uvm_field_int(post_mip, UVM_HEX)
    `uvm_field_int(mcycle, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "ibex_rvfi_item");
    super.new(name);
  endfunction
endclass

class ibex_rvfi_agent_cfg extends uvm_object;
  virtual ibex_rvfi_if vif;
  uvm_active_passive_enum is_active = UVM_PASSIVE;
  `uvm_object_utils_begin(ibex_rvfi_agent_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
  `uvm_object_utils_end
  function new(string name = "ibex_rvfi_agent_cfg");
    super.new(name);
  endfunction
endclass

class ibex_rvfi_monitor extends uvm_monitor;
  ibex_rvfi_agent_cfg cfg;
  virtual ibex_rvfi_if vif;
  uvm_analysis_port #(ibex_rvfi_item) ap;
  `uvm_component_utils(ibex_rvfi_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_rvfi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing RVFI agent cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    ibex_rvfi_item item;
    forever begin
      @(vif.mon_cb);
      // Complete dmem analysis first when response and retirement share a cycle.
      #1ps;
      if (vif.mon_cb.rst_n && (vif.mon_cb.valid || vif.mon_cb.ext_irq_valid)) begin
        item = ibex_rvfi_item::type_id::create("rvfi_item");
        item.irq_only = vif.mon_cb.ext_irq_valid && !vif.mon_cb.valid;
        item.order = vif.mon_cb.order;
        item.insn = vif.mon_cb.insn;
        item.trap = vif.mon_cb.trap;
        item.halt = vif.mon_cb.halt;
        item.intr = vif.mon_cb.intr;
        item.mode = vif.mon_cb.mode;
        item.ixl = vif.mon_cb.ixl;
        item.rs1_addr = vif.mon_cb.rs1_addr;
        item.rs2_addr = vif.mon_cb.rs2_addr;
        item.rs3_addr = vif.mon_cb.rs3_addr;
        item.rs1_rdata = vif.mon_cb.rs1_rdata;
        item.rs2_rdata = vif.mon_cb.rs2_rdata;
        item.rs3_rdata = vif.mon_cb.rs3_rdata;
        item.rd_addr = vif.mon_cb.rd_addr;
        item.rd_wdata = vif.mon_cb.rd_wdata;
        item.pc_rdata = vif.mon_cb.pc_rdata;
        item.pc_wdata = vif.mon_cb.pc_wdata;
        item.mem_addr = vif.mon_cb.mem_addr;
        item.mem_rmask = vif.mon_cb.mem_rmask;
        item.mem_wmask = vif.mon_cb.mem_wmask;
        item.mem_rdata = vif.mon_cb.mem_rdata;
        item.mem_wdata = vif.mon_cb.mem_wdata;
        item.pre_mip = vif.mon_cb.ext_pre_mip;
        item.post_mip = vif.mon_cb.ext_post_mip;
        item.nmi = vif.mon_cb.ext_nmi;
        item.nmi_int = vif.mon_cb.ext_nmi_int;
        item.debug_req = vif.mon_cb.ext_debug_req;
        item.debug_mode = vif.mon_cb.ext_debug_mode;
        item.rf_wr_suppress = vif.mon_cb.ext_rf_wr_suppress;
        item.mcycle = vif.mon_cb.ext_mcycle;
        for (int i = 0; i < 10; i++) begin
          item.mhpmcounters[i] = vif.mon_cb.ext_mhpmcounters[i];
          item.mhpmcountersh[i] = vif.mon_cb.ext_mhpmcountersh[i];
        end
        item.ic_scr_key_valid = vif.mon_cb.ext_ic_scr_key_valid;
        ap.write(item);
      end
    end
  endtask
endclass

class ibex_rvfi_agent extends uvm_agent;
  ibex_rvfi_agent_cfg cfg;
  ibex_rvfi_monitor monitor;
  `uvm_component_utils(ibex_rvfi_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_rvfi_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing RVFI agent cfg")
    uvm_config_db#(ibex_rvfi_agent_cfg)::set(this, "*", "cfg", cfg);
    monitor = ibex_rvfi_monitor::type_id::create("monitor", this);
  endfunction
endclass

