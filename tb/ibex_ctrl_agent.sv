typedef enum bit [1:0] {
  CTRL_RESET,
  CTRL_DEFAULTS,
  CTRL_DEBUG_PULSE
} ibex_ctrl_op_e;

class ibex_ctrl_item extends uvm_sequence_item;
  rand ibex_ctrl_op_e op;
  rand int unsigned cycles;
  bit rst_n;
  bit debug_req;
  bit [3:0] fetch_enable;
  bit [3:0] mcounteren_writable;

  constraint c_cycles { cycles inside {[1:1000]}; }

  `uvm_object_utils_begin(ibex_ctrl_item)
    `uvm_field_enum(ibex_ctrl_op_e, op, UVM_DEFAULT)
    `uvm_field_int(cycles, UVM_DEC)
    `uvm_field_int(rst_n, UVM_DEFAULT)
    `uvm_field_int(debug_req, UVM_DEFAULT)
    `uvm_field_int(fetch_enable, UVM_HEX)
    `uvm_field_int(mcounteren_writable, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "ibex_ctrl_item");
    super.new(name);
  endfunction
endclass

class ibex_ctrl_agent_cfg extends uvm_object;
  virtual ibex_ctrl_if vif;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  int unsigned reset_cycles = 20;
  bit [3:0] fetch_enable_value = 4'b0101;
  bit [3:0] mcounteren_writable_value = 4'b0101;

  `uvm_object_utils_begin(ibex_ctrl_agent_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(reset_cycles, UVM_DEC)
    `uvm_field_int(fetch_enable_value, UVM_HEX)
    `uvm_field_int(mcounteren_writable_value, UVM_HEX)
  `uvm_object_utils_end

  function new(string name = "ibex_ctrl_agent_cfg");
    super.new(name);
  endfunction
endclass

class ibex_ctrl_sequencer extends uvm_sequencer #(ibex_ctrl_item);
  `uvm_component_utils(ibex_ctrl_sequencer)
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction
endclass

class ibex_ctrl_driver extends uvm_driver #(ibex_ctrl_item);
  ibex_ctrl_agent_cfg cfg;
  virtual ibex_ctrl_if vif;

  `uvm_component_utils(ibex_ctrl_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_ctrl_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing control agent cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    ibex_ctrl_item item;
    vif.drv_cb.rst_n <= 1'b0;
    vif.drv_cb.debug_req <= 1'b0;
    vif.drv_cb.fetch_enable <= cfg.fetch_enable_value;
    vif.drv_cb.mcounteren_writable <= cfg.mcounteren_writable_value;
    vif.drv_cb.scramble_key_valid <= 1'b0;
    vif.drv_cb.scramble_key <= '0;
    vif.drv_cb.scramble_nonce <= '0;
    forever begin
      seq_item_port.get_next_item(item);
      case (item.op)
        CTRL_RESET: begin
          vif.drv_cb.rst_n <= 1'b0;
          repeat (item.cycles) @(vif.drv_cb);
          vif.drv_cb.rst_n <= 1'b1;
        end
        CTRL_DEFAULTS: begin
          vif.drv_cb.debug_req <= 1'b0;
          vif.drv_cb.fetch_enable <= cfg.fetch_enable_value;
          vif.drv_cb.mcounteren_writable <= cfg.mcounteren_writable_value;
        end
        CTRL_DEBUG_PULSE: begin
          vif.drv_cb.debug_req <= 1'b1;
          repeat (item.cycles) @(vif.drv_cb);
          vif.drv_cb.debug_req <= 1'b0;
        end
      endcase
      seq_item_port.item_done();
    end
  endtask
endclass

class ibex_ctrl_monitor extends uvm_monitor;
  ibex_ctrl_agent_cfg cfg;
  virtual ibex_ctrl_if vif;
  uvm_analysis_port #(ibex_ctrl_item) ap;
  bit last_rst_n = 1'bx;
  bit last_debug_req = 1'bx;

  `uvm_component_utils(ibex_ctrl_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    ap = new("ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_ctrl_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing control agent cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    ibex_ctrl_item item;
    forever begin
      @(vif.mon_cb);
      if ((vif.mon_cb.rst_n !== last_rst_n) ||
          (vif.mon_cb.debug_req !== last_debug_req)) begin
        item = ibex_ctrl_item::type_id::create("observed_ctrl");
        item.rst_n = vif.mon_cb.rst_n;
        item.debug_req = vif.mon_cb.debug_req;
        item.fetch_enable = vif.mon_cb.fetch_enable;
        item.mcounteren_writable = vif.mon_cb.mcounteren_writable;
        ap.write(item);
        last_rst_n = vif.mon_cb.rst_n;
        last_debug_req = vif.mon_cb.debug_req;
      end
    end
  endtask
endclass

class ibex_ctrl_agent extends uvm_agent;
  ibex_ctrl_agent_cfg cfg;
  ibex_ctrl_sequencer sequencer;
  ibex_ctrl_driver driver;
  ibex_ctrl_monitor monitor;

  `uvm_component_utils(ibex_ctrl_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_ctrl_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing control agent cfg")
    uvm_config_db#(ibex_ctrl_agent_cfg)::set(this, "*", "cfg", cfg);
    monitor = ibex_ctrl_monitor::type_id::create("monitor", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = ibex_ctrl_sequencer::type_id::create("sequencer", this);
      driver = ibex_ctrl_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE)
      driver.seq_item_port.connect(sequencer.seq_item_export);
  endfunction
endclass

class ibex_reset_seq extends uvm_sequence #(ibex_ctrl_item);
  int unsigned reset_cycles = 20;
  `uvm_object_utils(ibex_reset_seq)

  function new(string name = "ibex_reset_seq");
    super.new(name);
  endfunction

  task body();
    ibex_ctrl_item item = ibex_ctrl_item::type_id::create("reset_item");
    start_item(item);
    if (!item.randomize() with { op == CTRL_RESET; cycles == local::reset_cycles; })
      `uvm_fatal(get_name(), "Cannot randomize reset item")
    finish_item(item);
  endtask
endclass

class ibex_debug_pulse_seq extends uvm_sequence #(ibex_ctrl_item);
  rand int unsigned pulse_cycles;
  constraint c_pulse_cycles { pulse_cycles inside {[1:8]}; }
  `uvm_object_utils(ibex_debug_pulse_seq)

  function new(string name = "ibex_debug_pulse_seq");
    super.new(name);
  endfunction

  task body();
    ibex_ctrl_item item = ibex_ctrl_item::type_id::create("debug_item");
    start_item(item);
    if (!item.randomize() with { op == CTRL_DEBUG_PULSE; cycles == local::pulse_cycles; })
      `uvm_fatal(get_name(), "Cannot randomize debug item")
    finish_item(item);
  endtask
endclass


