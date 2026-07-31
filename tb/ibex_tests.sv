class ibex_base_test extends uvm_test;
  ibex_env_cfg cfg;
  ibex_env env;
  virtual ibex_mem_if imem_vif;
  virtual ibex_mem_if dmem_vif;
  virtual ibex_ctrl_if ctrl_vif;
  virtual ibex_irq_if irq_vif;
  virtual ibex_rvfi_if rvfi_vif;

  `uvm_component_utils(ibex_base_test)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    int value;
    super.build_phase(phase);
    cfg = ibex_env_cfg::type_id::create("cfg");
    if (!uvm_config_db#(virtual ibex_mem_if)::get(null, "", "imem_vif", imem_vif))
      `uvm_fatal(get_full_name(), "Missing imem_vif")
    if (!uvm_config_db#(virtual ibex_mem_if)::get(null, "", "dmem_vif", dmem_vif))
      `uvm_fatal(get_full_name(), "Missing dmem_vif")
    if (!uvm_config_db#(virtual ibex_ctrl_if)::get(null, "", "ctrl_vif", ctrl_vif))
      `uvm_fatal(get_full_name(), "Missing ctrl_vif")
    if (!uvm_config_db#(virtual ibex_irq_if)::get(null, "", "irq_vif", irq_vif))
      `uvm_fatal(get_full_name(), "Missing irq_vif")
    if (!uvm_config_db#(virtual ibex_rvfi_if)::get(null, "", "rvfi_vif", rvfi_vif))
      `uvm_fatal(get_full_name(), "Missing rvfi_vif")

    cfg.imem_cfg.vif = imem_vif;
    cfg.dmem_cfg.vif = dmem_vif;
    cfg.ctrl_cfg.vif = ctrl_vif;
    cfg.irq_cfg.vif = irq_vif;
    cfg.rvfi_cfg.vif = rvfi_vif;

    if (!$value$plusargs("bin=%s", cfg.binary_path))
      `uvm_fatal(get_full_name(), "Specify test binary with +bin=<path>")
    void'($value$plusargs("cosim_log=%s", cfg.cosim_log_path));
    void'($value$plusargs("isa=%s", cfg.isa_string));
    void'($value$plusargs("boot_addr=%h", cfg.boot_addr));
    void'($value$plusargs("signature_addr=%h", cfg.signature_addr));
    void'($value$plusargs("max_cycles=%d", cfg.max_cycles));
    if ($value$plusargs("enable_cosim=%d", value)) cfg.enable_cosim = value != 0;
    if ($value$plusargs("reset_cycles=%d", value)) cfg.ctrl_cfg.reset_cycles = value;
    if ($value$plusargs("imem_gnt_delay_max=%d", value)) cfg.imem_cfg.grant_delay_max = value;
    if ($value$plusargs("dmem_gnt_delay_max=%d", value)) cfg.dmem_cfg.grant_delay_max = value;
    if ($value$plusargs("imem_rsp_delay_max=%d", value)) cfg.imem_cfg.response_delay_max = value;
    if ($value$plusargs("dmem_rsp_delay_max=%d", value)) cfg.dmem_cfg.response_delay_max = value;

    cfg.start_pc = (cfg.boot_addr & 32'hffff_ff00) | 32'h80;
    cfg.start_mtvec = (cfg.boot_addr & 32'hffff_ff00) | 32'h01;
    configure_test();
    void'(cfg.mem.load_binary(cfg.binary_path, cfg.boot_addr));
    uvm_config_db#(ibex_env_cfg)::set(this, "env", "cfg", cfg);
    env = ibex_env::type_id::create("env", this);
  endfunction

  virtual function void configure_test();
  endfunction

  virtual task start_scenario();
  endtask

  task run_phase(uvm_phase phase);
    ibex_mem_response_seq imem_seq;
    ibex_mem_response_seq dmem_seq;
    ibex_reset_seq reset_seq;
    bit completed;
    phase.raise_objection(this);

    imem_seq = ibex_mem_response_seq::type_id::create("imem_seq");
    dmem_seq = ibex_mem_response_seq::type_id::create("dmem_seq");
    reset_seq = ibex_reset_seq::type_id::create("reset_seq");
    reset_seq.reset_cycles = cfg.ctrl_cfg.reset_cycles;
    fork
      imem_seq.start(env.virtual_sequencer.imem_sequencer);
      dmem_seq.start(env.virtual_sequencer.dmem_sequencer);
    join_none

    reset_seq.start(env.virtual_sequencer.ctrl_sequencer);
    fork
      start_scenario();
    join_none

    fork : completion_wait
      begin
        env.scoreboard.done_event.wait_trigger();
        completed = 1'b1;
      end
      begin
        repeat (cfg.max_cycles) @(posedge ctrl_vif.clk);
        if (!completed)
          `uvm_fatal(get_full_name(), $sformatf("Timeout after %0d cycles", cfg.max_cycles))
      end
    join_any
    disable completion_wait;

    repeat (cfg.drain_cycles) @(posedge ctrl_vif.clk);
    if (env.scoreboard.test_failed)
      `uvm_fatal(get_full_name(), "Test program or scoreboard reported failure")
    phase.drop_objection(this);
  endtask
endclass

class ibex_smoke_test extends ibex_base_test;
  `uvm_component_utils(ibex_smoke_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class ibex_waitstate_test extends ibex_base_test;
  `uvm_component_utils(ibex_waitstate_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    cfg.imem_cfg.grant_delay_max = 4;
    cfg.dmem_cfg.grant_delay_max = 4;
    cfg.imem_cfg.response_delay_max = 12;
    cfg.dmem_cfg.response_delay_max = 12;
  endfunction
endclass

class ibex_reset_test extends ibex_base_test;
  `uvm_component_utils(ibex_reset_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual task start_scenario();
    ibex_reset_seq reset_seq = ibex_reset_seq::type_id::create("midrun_reset_seq");
    repeat (40) @(posedge ctrl_vif.clk);
    reset_seq.reset_cycles = 5;
    reset_seq.start(env.virtual_sequencer.ctrl_sequencer);
  endtask
endclass

class ibex_irq_test extends ibex_base_test;
  `uvm_component_utils(ibex_irq_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual task start_scenario();
    ibex_random_irq_seq irq_seq = ibex_random_irq_seq::type_id::create("irq_seq");
    if (!irq_seq.randomize() with { num_pulses == 4; })
      `uvm_fatal(get_full_name(), "Cannot randomize IRQ sequence")
    irq_seq.start(env.virtual_sequencer.irq_sequencer);
  endtask
endclass

class ibex_single_instr_test extends ibex_base_test;
  `uvm_component_utils(ibex_single_instr_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Single instruction - all supported ISA", UVM_LOW)
  endfunction
endclass

class ibex_exception_illegal_test extends ibex_base_test;
  `uvm_component_utils(ibex_exception_illegal_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Exception / Illegal", UVM_LOW)
    cfg.imem_cfg.grant_delay_max = 0;
    cfg.dmem_cfg.grant_delay_max = 0;
  endfunction
endclass

class ibex_lsu_corner_test extends ibex_base_test;
  `uvm_component_utils(ibex_lsu_corner_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Memory / LSU corner", UVM_LOW)
    cfg.dmem_cfg.grant_delay_max = 3;
    cfg.dmem_cfg.response_delay_max = 8;
  endfunction
endclass

class ibex_branch_jump_test extends ibex_base_test;
  `uvm_component_utils(ibex_branch_jump_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Branch / Jump corner", UVM_LOW)
    cfg.imem_cfg.grant_delay_max = 2;
    cfg.imem_cfg.response_delay_max = 5;
  endfunction
endclass

class ibex_csr_priv_test extends ibex_base_test;
  `uvm_component_utils(ibex_csr_priv_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: CSR / Privileged", UVM_LOW)
  endfunction
endclass

class ibex_direct_irq_seq extends uvm_sequence #(ibex_irq_item);
  ibex_irq_kind_e kind = IRQ_SOFTWARE;
  int unsigned delay_cycles = 1;
  int unsigned pulse_cycles = 20;
  bit [3:0] fast_id = 0;
  `uvm_object_utils(ibex_direct_irq_seq)
  function new(string name = "ibex_direct_irq_seq");
    super.new(name);
  endfunction
  task body();
    ibex_irq_item item = ibex_irq_item::type_id::create("direct_irq_item");
    start_item(item);
    item.kind = kind;
    item.delay_cycles = delay_cycles;
    item.pulse_cycles = pulse_cycles;
    item.fast_id = fast_id;
    finish_item(item);
  endtask
endclass

class ibex_interrupt_debug_test extends ibex_base_test;
  `uvm_component_utils(ibex_interrupt_debug_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Interrupt / Debug", UVM_LOW)
    cfg.max_cycles = 20000;
  endfunction
  virtual task start_scenario();
    ibex_direct_irq_seq irq_seq;
    repeat (200) @(posedge ctrl_vif.clk);
    irq_seq = ibex_direct_irq_seq::type_id::create("software_irq_seq");
    irq_seq.kind = IRQ_SOFTWARE;
    irq_seq.delay_cycles = 1;
    irq_seq.pulse_cycles = 20;
    irq_seq.start(env.virtual_sequencer.irq_sequencer);
    `uvm_info(get_full_name(),
      "Debug request is not pulsed by default; debug entry/resume needs a debug ROM flow.",
      UVM_LOW)
  endtask
endclass

class ibex_pipeline_hazard_test extends ibex_base_test;
  `uvm_component_utils(ibex_pipeline_hazard_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "User testplan group: Pipeline / Hazard", UVM_LOW)
    cfg.dmem_cfg.grant_delay_max = 2;
    cfg.dmem_cfg.response_delay_max = 6;
  endfunction
endclass

class ibex_lsu_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_lsu_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure stress: LSU byte/half/word, lane offset and latency", UVM_LOW)
    cfg.dmem_cfg.grant_delay_max = 5;
    cfg.dmem_cfg.response_delay_max = 24;
    cfg.imem_cfg.response_delay_max = 8;
  endfunction
endclass

class ibex_exception_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_exception_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure stress: repeated illegal/system exceptions", UVM_LOW)
    cfg.max_cycles = 30000;
  endfunction
endclass

class ibex_irq_wfi_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_irq_wfi_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure stress: IRQ line sweep plus WFI wake by software IRQ", UVM_LOW)
    cfg.max_cycles = 50000;
  endfunction
  virtual task start_scenario();
    ibex_direct_irq_seq irq_seq;
    repeat (200) @(posedge ctrl_vif.clk);

    irq_seq = ibex_direct_irq_seq::type_id::create("timer_irq_seq");
    irq_seq.kind = IRQ_TIMER;
    irq_seq.delay_cycles = 1;
    irq_seq.pulse_cycles = 3;
    irq_seq.start(env.virtual_sequencer.irq_sequencer);

    irq_seq = ibex_direct_irq_seq::type_id::create("external_irq_seq");
    irq_seq.kind = IRQ_EXTERNAL;
    irq_seq.delay_cycles = 4;
    irq_seq.pulse_cycles = 3;
    irq_seq.start(env.virtual_sequencer.irq_sequencer);

    for (int unsigned i = 0; i < 15; i++) begin
      irq_seq = ibex_direct_irq_seq::type_id::create($sformatf("fast_irq_%0d_seq", i));
      irq_seq.kind = IRQ_FAST;
      irq_seq.fast_id = i;
      irq_seq.delay_cycles = 2;
      irq_seq.pulse_cycles = 2;
      irq_seq.start(env.virtual_sequencer.irq_sequencer);
    end

    irq_seq = ibex_direct_irq_seq::type_id::create("software_irq_wakeup_seq");
    irq_seq.kind = IRQ_SOFTWARE;
    irq_seq.delay_cycles = 20;
    irq_seq.pulse_cycles = 20;
    irq_seq.start(env.virtual_sequencer.irq_sequencer);

    `uvm_info(get_full_name(),
      "NMI is not pulsed in the stable IRQ/WFI stress because it is non-maskable and needs a dedicated handler.",
      UVM_LOW)
  endtask
endclass

class ibex_debug_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_debug_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure stress: debug_req pulse only; debug entry/DRET remain TODO", UVM_LOW)
    cfg.ctrl_cfg.mcounteren_writable_value = 4'b1111;
    cfg.drain_cycles = 40;
  endfunction
  virtual task start_scenario();
    ibex_debug_pulse_seq debug_seq;
    env.scoreboard.done_event.wait_trigger();
    repeat (4) @(posedge ctrl_vif.clk);
    debug_seq = ibex_debug_pulse_seq::type_id::create("post_pass_debug_req_seq");
    debug_seq.pulse_cycles = 4;
    debug_seq.start(env.virtual_sequencer.ctrl_sequencer);
  endtask
endclass

class ibex_reset_active_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_reset_active_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure stress: reset after memory/fetch activity", UVM_LOW)
    cfg.dmem_cfg.grant_delay_max = 4;
    cfg.dmem_cfg.response_delay_max = 16;
    cfg.imem_cfg.response_delay_max = 8;
    cfg.max_cycles = 50000;
  endfunction
  virtual task start_scenario();
    ibex_reset_seq reset_seq = ibex_reset_seq::type_id::create("active_transfer_reset_seq");
    repeat (80) @(posedge ctrl_vif.clk);
    reset_seq.reset_cycles = 6;
    reset_seq.start(env.virtual_sequencer.ctrl_sequencer);
  endtask
endclass

class ibex_trap_csr_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_trap_csr_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure pass2: trap CSR checking and repeated exception flow", UVM_LOW)
    cfg.max_cycles = 40000;
  endfunction
endclass

class ibex_mem_error_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_mem_error_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure pass2: targeted dmem error injection and access fault recovery", UVM_LOW)
    cfg.dmem_cfg.enable_data_error = 1'b1;
    cfg.dmem_cfg.data_error_addr = 32'h8000_2000;
    cfg.dmem_cfg.error_once = 0;
    cfg.dmem_cfg.grant_delay_max = 2;
    cfg.dmem_cfg.response_delay_max = 6;
    cfg.max_cycles = 50000;
  endfunction
endclass

class ibex_lsu_latency_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_lsu_latency_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure pass2: LSU latency and back-pressure sweep", UVM_LOW)
    cfg.imem_cfg.grant_delay_max = 2;
    cfg.imem_cfg.response_delay_min = 0;
    cfg.imem_cfg.response_delay_max = 10;
    cfg.dmem_cfg.grant_delay_max = 4;
    cfg.dmem_cfg.response_delay_min = 0;
    cfg.dmem_cfg.response_delay_max = 40;
    cfg.max_cycles = 80000;
  endfunction
endclass

class ibex_reset_recovery_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_reset_recovery_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure pass2: reset while memory traffic is active and post-reset recovery", UVM_LOW)
    cfg.dmem_cfg.grant_delay_max = 6;
    cfg.dmem_cfg.response_delay_max = 24;
    cfg.imem_cfg.grant_delay_max = 4;
    cfg.imem_cfg.response_delay_max = 12;
    cfg.max_cycles = 70000;
  endfunction
  virtual task start_scenario();
    ibex_reset_seq reset_seq = ibex_reset_seq::type_id::create("reset_recovery_midrun_seq");
    repeat (120) @(posedge ctrl_vif.clk);
    reset_seq.reset_cycles = 8;
    reset_seq.start(env.virtual_sequencer.ctrl_sequencer);
  endtask
endclass

class ibex_debug_entry_stress_test extends ibex_base_test;
  `uvm_component_utils(ibex_debug_entry_stress_test)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
  virtual function void configure_test();
    `uvm_info(get_full_name(), "Coverage closure experimental: debug_req pulse; debug entry/DRET require debug ROM support", UVM_LOW)
    cfg.ctrl_cfg.mcounteren_writable_value = 4'b1111;
    cfg.drain_cycles = 80;
    cfg.max_cycles = 50000;
  endfunction
  virtual task start_scenario();
    ibex_debug_pulse_seq debug_seq;
    repeat (80) @(posedge ctrl_vif.clk);
    debug_seq = ibex_debug_pulse_seq::type_id::create("debug_entry_req_seq");
    debug_seq.pulse_cycles = 4;
    debug_seq.start(env.virtual_sequencer.ctrl_sequencer);
  endtask
endclass
