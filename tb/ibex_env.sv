class ibex_env_cfg extends uvm_object;
  ibex_mem_agent_cfg imem_cfg;
  ibex_mem_agent_cfg dmem_cfg;
  ibex_ctrl_agent_cfg ctrl_cfg;
  ibex_irq_agent_cfg irq_cfg;
  ibex_rvfi_agent_cfg rvfi_cfg;
  ibex_sparse_mem mem;

  string binary_path;
  string cosim_log_path = "spike_cosim.log";
  string isa_string = "rv32imc";
  bit enable_cosim = 1'b1;
  bit [31:0] boot_addr = 32'h8000_0000;
  bit [31:0] start_pc = 32'h8000_0080;
  bit [31:0] start_mtvec = 32'h8000_0001;
  bit [31:0] signature_addr = 32'h8fff_fffc;
  bit [31:0] dm_start_addr = 32'h1a11_0000;
  bit [31:0] dm_end_addr = 32'h1a11_0fff;
  bit [31:0] pmp_num_regions = 0;
  bit [31:0] pmp_granularity = 0;
  bit [31:0] mhpm_counter_num = 0;
  bit secure_ibex = 0;
  bit icache = 0;
  longint unsigned max_cycles = 200000;
  int unsigned drain_cycles = 20;

  `uvm_object_utils_begin(ibex_env_cfg)
    `uvm_field_string(binary_path, UVM_DEFAULT)
    `uvm_field_string(cosim_log_path, UVM_DEFAULT)
    `uvm_field_string(isa_string, UVM_DEFAULT)
    `uvm_field_int(enable_cosim, UVM_DEFAULT)
    `uvm_field_int(boot_addr, UVM_HEX)
    `uvm_field_int(start_pc, UVM_HEX)
    `uvm_field_int(start_mtvec, UVM_HEX)
    `uvm_field_int(signature_addr, UVM_HEX)
    `uvm_field_int(max_cycles, UVM_DEC)
    `uvm_field_int(drain_cycles, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "ibex_env_cfg");
    super.new(name);
    imem_cfg = ibex_mem_agent_cfg::type_id::create("imem_cfg");
    dmem_cfg = ibex_mem_agent_cfg::type_id::create("dmem_cfg");
    ctrl_cfg = ibex_ctrl_agent_cfg::type_id::create("ctrl_cfg");
    irq_cfg = ibex_irq_agent_cfg::type_id::create("irq_cfg");
    rvfi_cfg = ibex_rvfi_agent_cfg::type_id::create("rvfi_cfg");
    mem = ibex_sparse_mem::type_id::create("shared_mem");
    imem_cfg.mem = mem;
    dmem_cfg.mem = mem;
    imem_cfg.is_instr = 1'b1;
    dmem_cfg.is_instr = 1'b0;
  endfunction
endclass

class ibex_virtual_sequencer extends uvm_sequencer;
  ibex_mem_sequencer imem_sequencer;
  ibex_mem_sequencer dmem_sequencer;
  ibex_ctrl_sequencer ctrl_sequencer;
  ibex_irq_sequencer irq_sequencer;
  `uvm_component_utils(ibex_virtual_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class ibex_spike_scoreboard extends uvm_scoreboard;
  ibex_env_cfg cfg;
  uvm_analysis_imp_dmem #(ibex_mem_txn, ibex_spike_scoreboard) dmem_export;
  uvm_analysis_imp_rvfi #(ibex_rvfi_item, ibex_spike_scoreboard) rvfi_export;
  uvm_analysis_imp_ctrl #(ibex_ctrl_item, ibex_spike_scoreboard) ctrl_export;
  uvm_event done_event;
  chandle cosim_handle;
  bit last_rst_n;
  bit test_failed;
  longint unsigned checks;
  longint unsigned passes;
  longint unsigned failures;

  `uvm_component_utils(ibex_spike_scoreboard)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    dmem_export = new("dmem_export", this);
    rvfi_export = new("rvfi_export", this);
    ctrl_export = new("ctrl_export", this);
    done_event = new("done_event");
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing environment cfg")
  endfunction

  function void cleanup_cosim();
    if (cosim_handle != null) ibex_spike_cosim_release(cosim_handle);
    cosim_handle = null;
  endfunction

  function void load_cosim_binary();
    int fd;
    int got;
    int count;
    bit [7:0] value;
    bit [31:0] addr = cfg.boot_addr;
    fd = $fopen(cfg.binary_path, "rb");
    if (fd == 0)
      `uvm_fatal(get_full_name(), $sformatf("Cannot open binary %s", cfg.binary_path))
    while (!$feof(fd)) begin
      got = $fread(value, fd);
      if (got == 1) begin
        riscv_cosim_write_mem_byte(cosim_handle, addr, value);
        addr++;
        count++;
      end
    end
    $fclose(fd);
    `uvm_info(get_full_name(), $sformatf("Loaded %0d bytes into Spike", count), UVM_LOW)
  endfunction

  function void init_cosim();
    if (!cfg.enable_cosim) return;
    cleanup_cosim();
    cosim_handle = ibex_spike_cosim_init(
      cfg.isa_string, cfg.start_pc, cfg.start_mtvec, cfg.cosim_log_path,
      cfg.pmp_num_regions, cfg.pmp_granularity, cfg.mhpm_counter_num,
      cfg.secure_ibex, cfg.icache, cfg.dm_start_addr, cfg.dm_end_addr);
    if (cosim_handle == null) `uvm_fatal(get_full_name(), "Spike initialization failed")
    load_cosim_binary();
  endfunction

  function string cosim_errors();
    string message = "Spike cosim mismatch:\n";
    for (int i = 0; i < riscv_cosim_get_num_errors(cosim_handle); i++)
      message = {message, riscv_cosim_get_error(cosim_handle, i), "\n"};
    riscv_cosim_clear_errors(cosim_handle);
    return message;
  endfunction

  function void write_ctrl(ibex_ctrl_item item);
    if (!item.rst_n && last_rst_n) cleanup_cosim();
    if (item.rst_n && !last_rst_n) init_cosim();
    last_rst_n = item.rst_n;
  endfunction

  function void write_dmem(ibex_mem_txn item);
    bit [31:0] access_data = item.we ? item.wdata : item.rdata;
    if (cfg.enable_cosim) begin
      if (cosim_handle == null)
        `uvm_fatal(get_full_name(), "Dmem transaction observed while Spike is inactive")
      riscv_cosim_notify_dside_access(
        cosim_handle, item.we, item.addr, access_data, item.be, item.error,
        item.misaligned_first, item.misaligned_second,
        item.misaligned_first_saw_error, item.m_mode_access);
    end

    if (item.we && ({item.addr[31:2], 2'b00} == (cfg.signature_addr - 4))) begin
      if (item.wdata[7:0] != 8'h01) begin
        test_failed = 1'b1;
        `uvm_error(get_full_name(), $sformatf(
          "Malformed RISC-V DV test-result signature 0x%08x", item.wdata))
      end else if (item.wdata[8]) begin
        test_failed = 1'b1;
        `uvm_error(get_full_name(), "RISC-V DV program reported TEST_FAIL")
      end else begin
        `uvm_info(get_full_name(), "RISC-V DV program reported TEST_PASS", UVM_LOW)
      end
      done_event.trigger();
    end
  endfunction

  function void write_rvfi(ibex_rvfi_item item);
    if (!cfg.enable_cosim) begin
      checks++;
      passes++;
      return;
    end
    if (cosim_handle == null)
      `uvm_fatal(get_full_name(), "RVFI item observed while Spike is inactive")

    riscv_cosim_set_debug_req(cosim_handle, item.debug_req);
    riscv_cosim_set_nmi(cosim_handle, item.nmi);
    riscv_cosim_set_nmi_int(cosim_handle, item.nmi_int);
    riscv_cosim_set_mip(cosim_handle, item.pre_mip, item.post_mip);
    if (item.irq_only) return;

    riscv_cosim_set_mcycle(cosim_handle, item.mcycle);
    for (int i = 0; i < cfg.mhpm_counter_num && i < 10; i++) begin
      riscv_cosim_set_csr(cosim_handle, 'hB03 + i, item.mhpmcounters[i]);
      riscv_cosim_set_csr(cosim_handle, 'hB83 + i, item.mhpmcountersh[i]);
    end
    riscv_cosim_set_ic_scr_key_valid(cosim_handle, item.ic_scr_key_valid);
    checks++;
    if (!riscv_cosim_step(cosim_handle, item.rd_addr, item.rd_wdata,
                          item.pc_rdata, item.trap, item.rf_wr_suppress)) begin
      failures++;
      test_failed = 1'b1;
      `uvm_fatal(get_full_name(), cosim_errors())
    end else begin
      passes++;
    end
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    `uvm_info(get_full_name(), $sformatf(
      "Scoreboard checks=%0d pass=%0d fail=%0d", checks, passes, failures), UVM_NONE)
    if (checks == 0) `uvm_error(get_full_name(), "Scoreboard was never triggered")
  endfunction

  function void final_phase(uvm_phase phase);
    if (cosim_handle != null)
      `uvm_info(get_full_name(), $sformatf("Spike matched %0d instructions",
        riscv_cosim_get_insn_cnt(cosim_handle)), UVM_LOW)
    cleanup_cosim();
    super.final_phase(phase);
  endfunction
endclass

`include "ibex_coverage_collector.sv"

class ibex_env extends uvm_env;
  ibex_env_cfg cfg;
  ibex_mem_agent imem_agent;
  ibex_mem_agent dmem_agent;
  ibex_ctrl_agent ctrl_agent;
  ibex_irq_agent irq_agent;
  ibex_rvfi_agent rvfi_agent;
  ibex_virtual_sequencer virtual_sequencer;
  ibex_spike_scoreboard scoreboard;
  ibex_coverage_collector coverage;

  `uvm_component_utils(ibex_env)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing environment cfg")
    uvm_config_db#(ibex_mem_agent_cfg)::set(this, "imem_agent", "cfg", cfg.imem_cfg);
    uvm_config_db#(ibex_mem_agent_cfg)::set(this, "dmem_agent", "cfg", cfg.dmem_cfg);
    uvm_config_db#(ibex_ctrl_agent_cfg)::set(this, "ctrl_agent", "cfg", cfg.ctrl_cfg);
    uvm_config_db#(ibex_irq_agent_cfg)::set(this, "irq_agent", "cfg", cfg.irq_cfg);
    uvm_config_db#(ibex_rvfi_agent_cfg)::set(this, "rvfi_agent", "cfg", cfg.rvfi_cfg);
    uvm_config_db#(ibex_env_cfg)::set(this, "scoreboard", "cfg", cfg);
    uvm_config_db#(ibex_env_cfg)::set(this, "coverage", "cfg", cfg);
    imem_agent = ibex_mem_agent::type_id::create("imem_agent", this);
    dmem_agent = ibex_mem_agent::type_id::create("dmem_agent", this);
    ctrl_agent = ibex_ctrl_agent::type_id::create("ctrl_agent", this);
    irq_agent = ibex_irq_agent::type_id::create("irq_agent", this);
    rvfi_agent = ibex_rvfi_agent::type_id::create("rvfi_agent", this);
    virtual_sequencer = ibex_virtual_sequencer::type_id::create("virtual_sequencer", this);
    scoreboard = ibex_spike_scoreboard::type_id::create("scoreboard", this);
    coverage = ibex_coverage_collector::type_id::create("coverage", this);
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    virtual_sequencer.imem_sequencer = imem_agent.sequencer;
    virtual_sequencer.dmem_sequencer = dmem_agent.sequencer;
    virtual_sequencer.ctrl_sequencer = ctrl_agent.sequencer;
    virtual_sequencer.irq_sequencer = irq_agent.sequencer;
    dmem_agent.monitor.completed_ap.connect(scoreboard.dmem_export);
    rvfi_agent.monitor.ap.connect(scoreboard.rvfi_export);
    ctrl_agent.monitor.ap.connect(scoreboard.ctrl_export);
    dmem_agent.monitor.completed_ap.connect(coverage.dmem_export);
    imem_agent.monitor.completed_ap.connect(coverage.imem_export);
    rvfi_agent.monitor.ap.connect(coverage.rvfi_export);
    irq_agent.monitor.ap.connect(coverage.irq_export);
    ctrl_agent.monitor.ap.connect(coverage.ctrl_export);
  endfunction
endclass
