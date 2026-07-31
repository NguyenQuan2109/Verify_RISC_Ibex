class ibex_mem_txn extends uvm_sequence_item;
  rand bit [31:0] addr;
  rand bit        we;
  rand bit [3:0]  be;
  rand bit [31:0] wdata;
       bit [31:0] rdata;
       bit        error;
       bit        misaligned_first;
       bit        misaligned_second;
       bit        misaligned_first_saw_error;
       bit        m_mode_access;
  rand int unsigned response_delay;
       int unsigned response_latency;

  `uvm_object_utils_begin(ibex_mem_txn)
    `uvm_field_int(addr, UVM_HEX)
    `uvm_field_int(we, UVM_DEFAULT)
    `uvm_field_int(be, UVM_HEX)
    `uvm_field_int(wdata, UVM_HEX)
    `uvm_field_int(rdata, UVM_HEX)
    `uvm_field_int(error, UVM_DEFAULT)
    `uvm_field_int(misaligned_first, UVM_DEFAULT)
    `uvm_field_int(misaligned_second, UVM_DEFAULT)
    `uvm_field_int(misaligned_first_saw_error, UVM_DEFAULT)
    `uvm_field_int(m_mode_access, UVM_DEFAULT)
    `uvm_field_int(response_delay, UVM_DEC)
    `uvm_field_int(response_latency, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "ibex_mem_txn");
    super.new(name);
  endfunction
endclass

class ibex_sparse_mem extends uvm_object;
  protected byte unsigned bytes[bit [31:0]];

  `uvm_object_utils(ibex_sparse_mem)

  function new(string name = "ibex_sparse_mem");
    super.new(name);
  endfunction

  function void clear();
    bytes.delete();
  endfunction

  function void write_word(bit [31:0] addr, bit [31:0] data, bit [3:0] be);
    bit [31:0] aligned = {addr[31:2], 2'b00};
    for (int i = 0; i < 4; i++) begin
      if (be[i]) bytes[aligned + i] = data[i*8 +: 8];
    end
  endfunction

  function bit [31:0] read_word(bit [31:0] addr, output bit initialized);
    bit [31:0] aligned = {addr[31:2], 2'b00};
    bit [31:0] data = '0;
    initialized = 1'b1;
    for (int i = 0; i < 4; i++) begin
      if (bytes.exists(aligned + i)) data[i*8 +: 8] = bytes[aligned + i];
      else initialized = 1'b0;
    end
    return data;
  endfunction

  function int unsigned load_binary(string path, bit [31:0] base_addr);
    int fd;
    int count;
    int got;
    bit [7:0] value;
    bit [31:0] addr = base_addr;
    fd = $fopen(path, "rb");
    if (fd == 0) `uvm_fatal(get_name(), $sformatf("Cannot open binary %s", path))
    while (!$feof(fd)) begin
      got = $fread(value, fd);
      if (got == 1) begin
        bytes[addr] = value;
        addr++;
        count++;
      end
    end
    $fclose(fd);
    `uvm_info(get_name(), $sformatf("Loaded %0d bytes at 0x%08x from %s",
                                    count, base_addr, path), UVM_LOW)
    return count;
  endfunction
endclass

class ibex_mem_agent_cfg extends uvm_object;
  virtual ibex_mem_if vif;
  ibex_sparse_mem mem;
  uvm_active_passive_enum is_active = UVM_ACTIVE;
  bit is_instr;
  int unsigned grant_delay_min = 0;
  int unsigned grant_delay_max = 0;
  int unsigned response_delay_min = 1;
  int unsigned response_delay_max = 3;
  bit error_enable = 0;
  int unsigned error_percent = 0;
  bit enable_instr_error = 0;
  bit enable_data_error = 0;
  bit [31:0] instr_error_addr = '0;
  bit [31:0] data_error_addr = '0;
  int unsigned error_once = 1;
  protected bit instr_error_seen;
  protected bit data_error_seen;

  `uvm_object_utils_begin(ibex_mem_agent_cfg)
    `uvm_field_enum(uvm_active_passive_enum, is_active, UVM_DEFAULT)
    `uvm_field_int(is_instr, UVM_DEFAULT)
    `uvm_field_int(grant_delay_min, UVM_DEC)
    `uvm_field_int(grant_delay_max, UVM_DEC)
    `uvm_field_int(response_delay_min, UVM_DEC)
    `uvm_field_int(response_delay_max, UVM_DEC)
    `uvm_field_int(error_enable, UVM_DEFAULT)
    `uvm_field_int(error_percent, UVM_DEC)
    `uvm_field_int(enable_instr_error, UVM_DEFAULT)
    `uvm_field_int(enable_data_error, UVM_DEFAULT)
    `uvm_field_int(instr_error_addr, UVM_HEX)
    `uvm_field_int(data_error_addr, UVM_HEX)
    `uvm_field_int(error_once, UVM_DEC)
  `uvm_object_utils_end

  function new(string name = "ibex_mem_agent_cfg");
    super.new(name);
  endfunction

  function bit should_inject_targeted_error(bit [31:0] addr);
    bit [31:0] aligned_addr = {addr[31:2], 2'b00};
    bit [31:0] aligned_instr_error_addr = {instr_error_addr[31:2], 2'b00};
    bit [31:0] aligned_data_error_addr = {data_error_addr[31:2], 2'b00};

    if (is_instr && enable_instr_error && aligned_addr == aligned_instr_error_addr) begin
      if (!error_once || !instr_error_seen) begin
        instr_error_seen = 1'b1;
        return 1'b1;
      end
    end

    if (!is_instr && enable_data_error && aligned_addr == aligned_data_error_addr) begin
      if (!error_once || !data_error_seen) begin
        data_error_seen = 1'b1;
        return 1'b1;
      end
    end

    return 1'b0;
  endfunction
endclass

class ibex_mem_sequencer extends uvm_sequencer #(ibex_mem_txn);
  uvm_tlm_analysis_fifo #(ibex_mem_txn) request_fifo;
  ibex_mem_agent_cfg cfg;

  `uvm_component_utils(ibex_mem_sequencer)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    request_fifo = new("request_fifo", this);
  endfunction
endclass

class ibex_mem_response_seq extends uvm_sequence #(ibex_mem_txn);
  `uvm_object_utils(ibex_mem_response_seq)
  `uvm_declare_p_sequencer(ibex_mem_sequencer)

  function new(string name = "ibex_mem_response_seq");
    super.new(name);
  endfunction

  task body();
    ibex_mem_txn req;
    ibex_mem_txn rsp;
    bit initialized;
    forever begin
      p_sequencer.request_fifo.get(req);
      rsp = ibex_mem_txn::type_id::create("rsp");
      rsp.copy(req);
      rsp.response_delay = $urandom_range(p_sequencer.cfg.response_delay_max,
                                          p_sequencer.cfg.response_delay_min);
      rsp.error = p_sequencer.cfg.should_inject_targeted_error(req.addr) ||
                  (p_sequencer.cfg.error_enable &&
                   ($urandom_range(99, 0) < p_sequencer.cfg.error_percent));
      if (rsp.error) begin
        `uvm_info(get_name(), $sformatf("%s error response injected at 0x%08x",
                  p_sequencer.cfg.is_instr ? "Instruction" : "Data", rsp.addr), UVM_LOW)
      end
      if (!rsp.error) begin
        if (rsp.we) begin
          p_sequencer.cfg.mem.write_word(rsp.addr, rsp.wdata, rsp.be);
          rsp.rdata = '0;
        end else begin
          rsp.rdata = p_sequencer.cfg.mem.read_word(rsp.addr, initialized);
          if (!initialized && p_sequencer.cfg.is_instr)
            `uvm_warning(get_name(), $sformatf("Fetch from uninitialized address 0x%08x", rsp.addr))
        end
      end
      start_item(rsp);
      finish_item(rsp);
    end
  endtask
endclass

class ibex_mem_driver extends uvm_driver #(ibex_mem_txn);
  ibex_mem_agent_cfg cfg;
  virtual ibex_mem_if vif;

  `uvm_component_utils(ibex_mem_driver)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_mem_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing memory agent cfg")
    vif = cfg.vif;
  endfunction

  task drive_grants();
    int unsigned countdown;
    bit grant_was_high;
    forever begin
      @(vif.drv_cb);
      if (!vif.drv_cb.rst_n) begin
        vif.drv_cb.gnt <= 1'b0;
        countdown = 0;
        grant_was_high = 0;
      end else if (grant_was_high) begin
        // One request completed. Ibex may keep req asserted for a back-to-back
        // transfer, so do not wait for req to drop.
        vif.drv_cb.gnt <= 1'b0;
        grant_was_high = 0;
        countdown = $urandom_range(cfg.grant_delay_max, cfg.grant_delay_min);
      end else if (!vif.drv_cb.req) begin
        vif.drv_cb.gnt <= 1'b0;
        countdown = $urandom_range(cfg.grant_delay_max, cfg.grant_delay_min);
      end else if (countdown != 0) begin
        vif.drv_cb.gnt <= 1'b0;
        countdown--;
      end else begin
        vif.drv_cb.gnt <= 1'b1;
        grant_was_high = 1;
      end
    end
  endtask

  task drive_responses();
    ibex_mem_txn rsp;
    forever begin
      seq_item_port.get_next_item(rsp);
      repeat (rsp.response_delay) begin
        @(vif.drv_cb);
        if (!vif.drv_cb.rst_n) break;
      end
      if (vif.drv_cb.rst_n) begin
        vif.drv_cb.rdata  <= rsp.rdata;
        vif.drv_cb.rintg  <= '0;
        vif.drv_cb.error  <= rsp.error;
        vif.drv_cb.rvalid <= 1'b1;
        @(vif.drv_cb);
      end
      vif.drv_cb.rvalid <= 1'b0;
      vif.drv_cb.error  <= 1'b0;
      seq_item_port.item_done();
    end
  endtask

  task run_phase(uvm_phase phase);
    vif.drv_cb.gnt    <= 1'b0;
    vif.drv_cb.rvalid <= 1'b0;
    vif.drv_cb.rdata  <= '0;
    vif.drv_cb.rintg  <= '0;
    vif.drv_cb.error  <= 1'b0;
    fork
      drive_grants();
      drive_responses();
    join
  endtask
endclass

class ibex_mem_monitor extends uvm_monitor;
  ibex_mem_agent_cfg cfg;
  virtual ibex_mem_if vif;
  uvm_analysis_port #(ibex_mem_txn) request_ap;
  uvm_analysis_port #(ibex_mem_txn) completed_ap;
  ibex_mem_txn pending[$];
  longint unsigned cycle_count;
  longint unsigned request_cycle[$];

  `uvm_component_utils(ibex_mem_monitor)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    request_ap = new("request_ap", this);
    completed_ap = new("completed_ap", this);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_mem_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing memory agent cfg")
    vif = cfg.vif;
  endfunction

  task run_phase(uvm_phase phase);
    ibex_mem_txn tr;
    ibex_mem_txn req_copy;
    forever begin
      @(vif.mon_cb);
      cycle_count++;
      if (!vif.mon_cb.rst_n) begin
        pending.delete();
        request_cycle.delete();
        continue;
      end
      if (vif.mon_cb.req && vif.mon_cb.gnt) begin
        tr = ibex_mem_txn::type_id::create("request");
        tr.addr = vif.mon_cb.addr;
        tr.we = cfg.is_instr ? 1'b0 : vif.mon_cb.we;
        tr.be = cfg.is_instr ? 4'b0 : vif.mon_cb.be;
        tr.wdata = cfg.is_instr ? 32'b0 : vif.mon_cb.wdata;
        tr.misaligned_first = vif.mon_cb.misaligned_first;
        tr.misaligned_second = vif.mon_cb.misaligned_second;
        tr.misaligned_first_saw_error = vif.mon_cb.misaligned_first_saw_error;
        tr.m_mode_access = vif.mon_cb.m_mode_access;
        pending.push_back(tr);
        request_cycle.push_back(cycle_count);
        $cast(req_copy, tr.clone());
        request_ap.write(req_copy);
      end
      if (vif.mon_cb.rvalid) begin
        if (pending.size() == 0) begin
          `uvm_error(get_full_name(), "Response observed without a pending request")
        end else begin
          tr = pending.pop_front();
          tr.response_latency = cycle_count - request_cycle.pop_front();
          tr.rdata = vif.mon_cb.rdata;
          tr.error = vif.mon_cb.error;
          completed_ap.write(tr);
        end
      end
    end
  endtask
endclass

class ibex_mem_agent extends uvm_agent;
  ibex_mem_agent_cfg cfg;
  ibex_mem_sequencer sequencer;
  ibex_mem_driver driver;
  ibex_mem_monitor monitor;

  `uvm_component_utils(ibex_mem_agent)

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_mem_agent_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing memory agent cfg")
    uvm_config_db#(ibex_mem_agent_cfg)::set(this, "*", "cfg", cfg);
    monitor = ibex_mem_monitor::type_id::create("monitor", this);
    if (cfg.is_active == UVM_ACTIVE) begin
      sequencer = ibex_mem_sequencer::type_id::create("sequencer", this);
      sequencer.cfg = cfg;
      driver = ibex_mem_driver::type_id::create("driver", this);
    end
  endfunction

  function void connect_phase(uvm_phase phase);
    super.connect_phase(phase);
    if (cfg.is_active == UVM_ACTIVE) begin
      driver.seq_item_port.connect(sequencer.seq_item_export);
      monitor.request_ap.connect(sequencer.request_fifo.analysis_export);
    end
  endfunction
endclass
