typedef enum bit [2:0] {
  IRQ_SOFTWARE,
  IRQ_TIMER,
  IRQ_EXTERNAL,
  IRQ_FAST,
  IRQ_NMI
} ibex_irq_kind_e;

class ibex_irq_item extends uvm_sequence_item;
  rand ibex_irq_kind_e kind;
  rand bit [3:0] fast_id;
  rand int unsigned delay_cycles;
  rand int unsigned pulse_cycles;
  bit irq_software, irq_timer, irq_external, irq_nm;
  bit [14:0] irq_fast;

  constraint c_delay { delay_cycles inside {[1:1000]}; }
  constraint c_pulse { pulse_cycles inside {[1:32]}; }
  constraint c_fast_id { fast_id inside {[0:14]}; }

  `uvm_object_utils_begin(ibex_irq_item)
    `uvm_field_enum(ibex_irq_kind_e, kind, UVM_DEFAULT)
    `uvm_field_int(fast_id, UVM_DEC)
    `uvm_field_int(delay_cycles, UVM_DEC)
    `uvm_field_int(pulse_cycles, UVM_DEC)
    `uvm_field_int(irq_software, UVM_DEFAULT)
    `uvm_field_int(irq_timer, UVM_DEFAULT)
    `uvm_field_int(irq_external, UVM_DEFAULT)
    `uvm_field_int(irq_fast, UVM_HEX)
    `uvm_field_int(irq_nm, UVM_DEFAULT)
  `uvm_object_utils_end

  function new(string name = "ibex_irq_item");
    super.new(name);
  endfunction
endclass

class ibex_irq_agent_cfg extends uvm_object;
  virtual ibex_irq_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  `uvm_object_utils_begin(ibex_irq_agent_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
  `uvm_object_utils_end
  function new(string name = "ibex_irq_agent_cfg");
    super.new(name);
  endfunction
endclass

class ibex_irq_sequencer extends uvm_sequencer #(ibex_irq_item);
  `uvm_component_utils(ibex_irq_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class ibex_irq_driver extends uvm_driver #(ibex_irq_item);
  ibex_irq_agent_cfg cfg;
  virtual ibex_irq_if vif;
  `uvm_component_utils(ibex_irq_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_irq_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing IRQ agent cfg")
    vif = cfg.vif;
  endfunction

  task clear_irqs();
    vif.drv_cb.irq_software <= 1'b0;
    vif.drv_cb.irq_timer <= 1'b0;
    vif.drv_cb.irq_external <= 1'b0;
    vif.drv_cb.irq_fast <= '0;
    vif.drv_cb.irq_nm <= 1'b0;
  endtask

  task run_phase(uvm_phase phase);
    ibex_irq_item item;
    clear_irqs();
    forever begin
      seq_item_port.get_next_item(item);
      repeat (item.delay_cycles) @(vif.drv_cb);
      case (item.kind)
        IRQ_SOFTWARE: vif.drv_cb.irq_software <= 1'b1;
        IRQ_TIMER:    vif.drv_cb.irq_timer <= 1'b1;
        IRQ_EXTERNAL: vif.drv_cb.irq_external <= 1'b1;
        IRQ_FAST:     vif.drv_cb.irq_fast[item.fast_id] <= 1'b1;
        IRQ_NMI:      vif.drv_cb.irq_nm <= 1'b1;
      endcase
      repeat (item.pulse_cycles) @(vif.drv_cb);
      clear_irqs();
      seq_item_port.item_done();
    end
  endtask
endclass

class ibex_irq_monitor extends uvm_monitor;
  ibex_irq_agent_cfg cfg;
  virtual ibex_irq_if vif;
  uvm_analysis_port #(ibex_irq_item) ap;
  bit [18:0] last_irqs = 'x;

  `uvm_component_utils(ibex_irq_monitor)
  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_irq_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing IRQ agent cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    ibex_irq_item item;
    bit [18:0] current;
    forever begin
      @(vif.mon_cb);
      current = {vif.mon_cb.irq_nm, vif.mon_cb.irq_fast,
                 vif.mon_cb.irq_external, vif.mon_cb.irq_timer,
                 vif.mon_cb.irq_software};
      if (current !== last_irqs) begin
        item = ibex_irq_item::type_id::create("observed_irq");
        item.irq_software = vif.mon_cb.irq_software;
        item.irq_timer = vif.mon_cb.irq_timer;
        item.irq_external = vif.mon_cb.irq_external;
        item.irq_fast = vif.mon_cb.irq_fast;
        item.irq_nm = vif.mon_cb.irq_nm;
        ap.write(item);
        last_irqs = current;
      end
    end
  endtask
endclass

class ibex_irq_agent extends uvm_agent;
  ibex_irq_agent_cfg cfg;
  ibex_irq_sequencer sequencer;
  ibex_irq_driver driver;
  ibex_irq_monitor monitor;
  `uvm_component_utils(ibex_irq_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_irq_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing IRQ agent cfg")
    uvm_config_db#(ibex_irq_agent_cfg)::set(this, "*", "cfg", cfg);
    monitor = ibex_irq_monitor::type_id::create("monitor", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = ibex_irq_sequencer::type_id::create("sequencer", this);
      driver = ibex_irq_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class ibex_random_irq_seq extends uvm_sequence #(ibex_irq_item);
  rand int unsigned num_pulses = 4;
  constraint c_num_pulses { num_pulses inside {[1:16]}; }
  `uvm_object_utils(ibex_random_irq_seq)

  function new(string name = "ibex_random_irq_seq");
    super.new(name);
  endfunction

  task body();
    repeat (num_pulses) begin
      ibex_irq_item item = ibex_irq_item::type_id::create("irq_item");
      start_item(item);
      if (!item.randomize()) `uvm_fatal(get_name(), "Cannot randomize IRQ item")
      finish_item(item);
    end
  endtask
endclass


