class ibex_coverage_collector extends uvm_component;
  ibex_env_cfg cfg;
  uvm_analysis_imp_cov_dmem #(ibex_mem_txn, ibex_coverage_collector) dmem_export;
  uvm_analysis_imp_cov_imem #(ibex_mem_txn, ibex_coverage_collector) imem_export;
  uvm_analysis_imp_cov_rvfi #(ibex_rvfi_item, ibex_coverage_collector) rvfi_export;
  uvm_analysis_imp_cov_irq #(ibex_irq_item, ibex_coverage_collector) irq_export;
  uvm_analysis_imp_cov_ctrl #(ibex_ctrl_item, ibex_coverage_collector) ctrl_export;

  bit saw_reset_asserted;
  bit saw_reset_deasserted;
  bit saw_activity_before_reset;
  bit first_retire_seen;
  bit [15:0] observed_opcode_classes;
  bit [7:0] observed_alu_funct3;
  bit seen_dmem_load;
  bit seen_dmem_store;
  bit seen_branch;
  bit seen_jump;
  bit seen_csr_op;
  bit seen_mret;
  bit seen_irq_pulse;
  bit seen_irq_trap;
  bit seen_debug_req_pulse;
  bit seen_debug_entry;
  bit have_last_rvfi;
  bit [31:0] last_insn;
  bit [4:0] last_rd;
  bit last_has_rd;
  bit last_was_alu;
  bit last_was_load;
  bit last_was_store;
  bit last_was_branch_jump;

  bit hit_f001_reset_bootstrap;
  bit hit_f002_imem_protocol;
  bit hit_f003_dmem_load_store;
  bit hit_f004_rv32i_alu;
  bit hit_f005_m_extension;
  bit hit_f006_c_extension;
  bit hit_f007_branch_jump;
  bit hit_f008_trap_exception;
  bit hit_f009_interrupt;
  bit hit_f010_csr_privilege;
  bit hit_f011_memory_backpressure;
  bit hit_f012_reset_active_transfer;
  bit hit_f013_debug_request;
  bit hit_f014_random_isa_stream;
  bit hit_f015_arch_equivalence;

  function int unsigned opcode_class(bit [31:0] insn);
    if (insn[1:0] != 2'b11) return 12;
    unique case (insn[6:0])
      7'b0110111: return 0;
      7'b0010111: return 1;
      7'b1101111: return 2;
      7'b1100111: return 3;
      7'b1100011: return 4;
      7'b0000011: return 5;
      7'b0100011: return 6;
      7'b0010011: return 7;
      7'b0110011: return 8;
      7'b0001111: return 9;
      7'b1110011: return 10;
      default:    return 11;
    endcase
  endfunction

  function bit is_rv32i_alu(bit [31:0] insn);
    if (insn[1:0] != 2'b11) return 1'b0;
    if (insn[6:0] == 7'b0010011) return 1'b1;
    if (insn[6:0] == 7'b0110011 && insn[31:25] != 7'b0000001) return 1'b1;
    return 1'b0;
  endfunction

  function bit is_m_extension(bit [31:0] insn);
    return insn[1:0] == 2'b11 && insn[6:0] == 7'b0110011 && insn[31:25] == 7'b0000001;
  endfunction

  function bit is_branch_or_jump(bit [31:0] insn);
    return insn[1:0] == 2'b11 &&
           (insn[6:0] == 7'b1100011 || insn[6:0] == 7'b1101111 ||
            insn[6:0] == 7'b1100111);
  endfunction

  function bit is_branch(bit [31:0] insn);
    return insn[1:0] == 2'b11 && insn[6:0] == 7'b1100011;
  endfunction

  function bit is_jump(bit [31:0] insn);
    return insn[1:0] == 2'b11 &&
           (insn[6:0] == 7'b1101111 || insn[6:0] == 7'b1100111);
  endfunction

  function bit is_load(bit [31:0] insn);
    return insn[1:0] == 2'b11 && insn[6:0] == 7'b0000011;
  endfunction

  function bit is_store(bit [31:0] insn);
    return insn[1:0] == 2'b11 && insn[6:0] == 7'b0100011;
  endfunction

  function bit is_csr(bit [31:0] insn);
    return insn[1:0] == 2'b11 && insn[6:0] == 7'b1110011 && insn[14:12] != 3'b000;
  endfunction

  function int unsigned system_instr_kind(bit [31:0] insn);
    if (insn[1:0] != 2'b11 || insn[6:0] != 7'b1110011) return 0;
    unique case (insn)
      32'h0000_0073: return 1;
      32'h0010_0073: return 2;
      32'h3020_0073: return 3;
      32'h1050_0073: return 4;
      32'h7b20_0073: return 5;
      default: begin
        if (insn[14:12] != 3'b000) return 6;
        return 7;
      end
    endcase
  endfunction

  function int unsigned mem_access_kind(bit [3:0] rmask, bit [3:0] wmask);
    if (rmask != 4'b0000 && wmask != 4'b0000) return 3;
    if (rmask != 4'b0000) return 1;
    if (wmask != 4'b0000) return 2;
    return 0;
  endfunction

  function int unsigned be_size(bit [3:0] be);
    unique case (be)
      4'b0001, 4'b0010, 4'b0100, 4'b1000: return 1;
      4'b0011, 4'b1100: return 2;
      4'b1111: return 4;
      default: return 0;
    endcase
  endfunction

  function int unsigned be_lane_offset(bit [3:0] be);
    unique case (be)
      4'b0001, 4'b0011, 4'b1111: return 0;
      4'b0010: return 1;
      4'b0100, 4'b1100: return 2;
      4'b1000: return 3;
      default: return 0;
    endcase
  endfunction

  function int unsigned bus_lane_offset(bit [31:0] addr, bit [3:0] be);
    if (be != 4'b0000 && addr[1:0] == 2'b00) return be_lane_offset(be);
    return addr[1:0];
  endfunction

  function bit access_aligned(bit [31:0] addr, bit [3:0] be);
    unique case (be_size(be))
      1: return 1'b1;
      2: return bus_lane_offset(addr, be) inside {0, 2};
      4: return bus_lane_offset(addr, be) == 0;
      default: return addr[1:0] == 0;
    endcase
  endfunction

  function int unsigned pc_delta_kind(bit [31:0] pc, bit [31:0] next_pc);
    if (next_pc == pc + 32'd4) return 0;
    if (next_pc == pc + 32'd2) return 1;
    if (next_pc < pc) return 2;
    if (next_pc > pc) return 3;
    return 4;
  endfunction

  function int unsigned count_opcode_classes();
    int unsigned count;
    for (int i = 0; i < 16; i++) count += observed_opcode_classes[i];
    return count;
  endfunction

  function bit has_rs1_dep(ibex_rvfi_item item);
    return have_last_rvfi && last_has_rd && last_rd != 0 && item.rs1_addr == last_rd;
  endfunction

  function bit has_rs2_dep(ibex_rvfi_item item);
    return have_last_rvfi && last_has_rd && last_rd != 0 && item.rs2_addr == last_rd;
  endfunction

  covergroup rvfi_cg with function sample(ibex_rvfi_item item);
    option.per_instance = 1;
    opcode: coverpoint opcode_class(item.insn) {
      bins lui = {0};
      bins auipc = {1};
      bins jal = {2};
      bins jalr = {3};
      bins branch = {4};
      bins load = {5};
      bins store = {6};
      bins op_imm = {7};
      bins op = {8};
      bins fence = {9};
      bins system = {10};
      bins other_32b = {11};
      bins compressed = {12};
    }
    compressed: coverpoint (item.insn[1:0] != 2'b11);
    compressed_quadrant: coverpoint item.insn[1:0] iff (item.insn[1:0] != 2'b11) {
      bins q0 = {2'b00};
      bins q1 = {2'b01};
      bins q2 = {2'b10};
    }
    compressed_funct3: coverpoint item.insn[15:13] iff (item.insn[1:0] != 2'b11);
    alu_funct3: coverpoint item.insn[14:12] iff (is_rv32i_alu(item.insn)) {
      bins add_sub_addi = {3'b000};
      bins sll_slli = {3'b001};
      bins slt_slti = {3'b010};
      bins sltu_sltiu = {3'b011};
      bins xor_xori = {3'b100};
      bins srl_sra_srli_srai = {3'b101};
      bins or_ori = {3'b110};
      bins and_andi = {3'b111};
    }
    alu_sub_sra_bit: coverpoint item.insn[30] iff (is_rv32i_alu(item.insn) &&
      (item.insn[14:12] == 3'b000 || item.insn[14:12] == 3'b101));
    muldiv_funct3: coverpoint item.insn[14:12] iff (is_m_extension(item.insn)) {
      bins mul = {3'b000};
      bins mulh = {3'b001};
      bins mulhsu = {3'b010};
      bins mulhu = {3'b011};
      bins div = {3'b100};
      bins divu = {3'b101};
      bins rem = {3'b110};
      bins remu = {3'b111};
    }
    branch_funct3: coverpoint item.insn[14:12] iff (item.insn[1:0] == 2'b11 &&
      item.insn[6:0] == 7'b1100011) {
      bins beq = {3'b000};
      bins bne = {3'b001};
      bins blt = {3'b100};
      bins bge = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};
    }
    csr_funct3: coverpoint item.insn[14:12] iff (is_csr(item.insn)) {
      bins csrrw = {3'b001};
      bins csrrs = {3'b010};
      bins csrrc = {3'b011};
      bins csrrwi = {3'b101};
      bins csrrsi = {3'b110};
      bins csrrci = {3'b111};
    }
    system_kind: coverpoint system_instr_kind(item.insn) {
      bins ecall = {1};
      bins ebreak = {2};
      bins mret = {3};
      bins wfi = {4};
      bins dret = {5};
      bins csr = {6};
      bins other_system = {7};
    }
    trap: coverpoint item.trap;
    intr: coverpoint item.intr;
    halt: coverpoint item.halt;
    debug_req: coverpoint item.debug_req;
    debug_mode: coverpoint item.debug_mode;
    rf_wr_suppress: coverpoint item.rf_wr_suppress;
    mode: coverpoint item.mode {
      bins user = {2'b00};
      bins machine = {2'b11};
      illegal_bins reserved = {2'b01, 2'b10};
    }
    rd: coverpoint item.rd_addr { bins zero = {0}; bins gpr[] = {[1:31]}; }
    rs1: coverpoint item.rs1_addr { bins zero = {0}; bins gpr[] = {[1:31]}; }
    rs2: coverpoint item.rs2_addr { bins zero = {0}; bins gpr[] = {[1:31]}; }
    rvfi_mem_access: coverpoint mem_access_kind(item.mem_rmask, item.mem_wmask) {
      bins none = {0};
      bins load = {1};
      bins store = {2};
      bins read_write_same_retire = {3};
    }
    rvfi_mem_alignment: coverpoint item.mem_addr[1:0] iff
      (item.mem_rmask != 4'b0000 || item.mem_wmask != 4'b0000);
    rvfi_mem_size: coverpoint be_size(item.mem_rmask | item.mem_wmask) iff
      (item.mem_rmask != 4'b0000 || item.mem_wmask != 4'b0000) {
      bins byte_access = {1};
      bins halfword_access = {2};
      bins word_access = {4};
      bins split_or_other = {0};
    }
    pc_delta: coverpoint pc_delta_kind(item.pc_rdata, item.pc_wdata) {
      bins sequential_32b = {0};
      bins sequential_16b = {1};
      bins backward = {2};
      bins forward_nonseq = {3};
      bins same_or_other = {4};
    }
    branch_jump_pc_delta: coverpoint pc_delta_kind(item.pc_rdata, item.pc_wdata)
      iff (is_branch_or_jump(item.insn)) {
      bins sequential_32b = {0};
      bins sequential_16b = {1};
      bins backward = {2};
      bins forward_nonseq = {3};
      bins same_or_other = {4};
    }
    opcode_x_trap: cross opcode, trap;
    opcode_x_rd: cross opcode, rd;
    compressed_x_trap: cross compressed, trap;
    mode_x_trap: cross mode, trap;
    mode_x_intr: cross mode, intr;
    csr_x_mode: cross csr_funct3, mode;
    branch_x_pc_delta: cross branch_funct3, branch_jump_pc_delta;
  endgroup

  covergroup mem_cg with function sample(ibex_mem_txn item, bit is_dmem);
    option.per_instance = 1;
    bus_kind: coverpoint is_dmem {
      bins imem = {0};
      bins dmem = {1};
    }
    direction: coverpoint item.we;
    byte_enable: coverpoint item.be {
      bins byte_lanes[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins halfword_lanes[] = {4'b0011, 4'b1100};
      bins word = {4'b1111};
      bins split_or_other = default;
    }
    access_size: coverpoint be_size(item.be) {
      bins byte_access = {1};
      bins halfword_access = {2};
      bins word_access = {4};
      bins split_or_other = {0};
    }
    alignment: coverpoint bus_lane_offset(item.addr, item.be) {
      bins lane0 = {0};
      bins lane1 = {1};
      bins lane2 = {2};
      bins lane3 = {3};
    }
    latency: coverpoint item.response_latency {
      bins zero = {0};
      bins one_cycle = {1};
      bins short[] = {[2:3]};
      bins mid_latency = {[4:15]};
      bins long_latency = {[16:255]};
    }
    error: coverpoint item.error;
    misaligned_first: coverpoint item.misaligned_first;
    misaligned_second: coverpoint item.misaligned_second;
    misaligned_first_saw_error: coverpoint item.misaligned_first_saw_error;
    m_mode_access: coverpoint item.m_mode_access;
    direction_x_be: cross direction, byte_enable;
    bus_x_latency: cross bus_kind, latency;
    size_x_alignment: cross access_size, alignment;
    error_x_bus: cross error, bus_kind;
    misaligned_x_error: cross misaligned_first, misaligned_second, error;
  endgroup

  covergroup single_instr_cg with function sample(ibex_rvfi_item item);
    option.per_instance = 1;
    instr_class: coverpoint opcode_class(item.insn) {
      bins r_type = {8};
      bins i_type = {7};
      bins load = {5};
      bins store = {6};
      bins branch = {4};
      bins jal = {2};
      bins jalr = {3};
      bins lui = {0};
      bins auipc = {1};
      bins system = {10};
      bins compressed = {12};
    }
    rv32i_r_funct3: coverpoint item.insn[14:12] iff (item.insn[1:0] == 2'b11 &&
      item.insn[6:0] == 7'b0110011 && item.insn[31:25] != 7'b0000001);
    rv32i_i_funct3: coverpoint item.insn[14:12] iff (item.insn[1:0] == 2'b11 &&
      item.insn[6:0] == 7'b0010011);
    rd_index: coverpoint item.rd_addr { bins x0 = {0}; bins gpr[] = {[1:31]}; }
    rs1_index: coverpoint item.rs1_addr { bins x0 = {0}; bins gpr[] = {[1:31]}; }
    rs2_index: coverpoint item.rs2_addr { bins x0 = {0}; bins gpr[] = {[1:31]}; }
    m_ext: coverpoint is_m_extension(item.insn);
    c_ext: coverpoint (item.insn[1:0] != 2'b11);
    x0_corner: cross instr_class, rd_index;
  endgroup

  covergroup exception_illegal_cg with function sample(ibex_rvfi_item item);
    option.per_instance = 1;
    trap_seen: coverpoint item.trap;
    system_seen: coverpoint system_instr_kind(item.insn) {
      bins ecall = {1};
      bins ebreak = {2};
      bins mret = {3};
      bins wfi = {4};
      bins dret = {5};
      bins csr = {6};
      bins other_system = {7};
    }
    illegal_like: coverpoint (item.trap && system_instr_kind(item.insn) == 0);
    trap_pc_delta: coverpoint pc_delta_kind(item.pc_rdata, item.pc_wdata) iff (item.trap) {
      bins sequential_32b = {0};
      bins sequential_16b = {1};
      bins backward = {2};
      bins forward_nonseq = {3};
      bins same_or_other = {4};
    }
    trap_x_system: cross trap_seen, system_seen;
  endgroup

  covergroup lsu_corner_cg with function sample(ibex_mem_txn item, bit is_dmem);
    option.per_instance = 1;
    bus_kind: coverpoint is_dmem { bins imem = {0}; bins dmem = {1}; }
    direction: coverpoint item.we;
    be: coverpoint item.be {
      bins no_access = {4'b0000};
      bins byte_lanes[] = {4'b0001, 4'b0010, 4'b0100, 4'b1000};
      bins halfword_lanes[] = {4'b0011, 4'b1100};
      bins word = {4'b1111};
      bins split_or_other = default;
    }
    size: coverpoint be_size(item.be) {
      bins byte_access = {1};
      bins halfword_access = {2};
      bins word_access = {4};
      bins other = {0};
    }
    offset: coverpoint bus_lane_offset(item.addr, item.be) {
      bins lane0 = {0};
      bins lane1 = {1};
      bins lane2 = {2};
      bins lane3 = {3};
    }
    aligned: coverpoint access_aligned(item.addr, item.be);
    latency: coverpoint item.response_latency {
      bins zero = {0};
      bins one = {1};
      bins short = {[2:3]};
      bins mid = {[4:15]};
      bins long = {[16:255]};
    }
    error: coverpoint item.error;
    dmem_size_x_offset: cross bus_kind, direction, size, offset;
    write_be_x_offset: cross direction, be, offset;
  endgroup

  covergroup branch_jump_cg with function sample(ibex_rvfi_item item);
    option.per_instance = 1;
    branch_type: coverpoint item.insn[14:12] iff (is_branch(item.insn)) {
      bins beq = {3'b000};
      bins bne = {3'b001};
      bins blt = {3'b100};
      bins bge = {3'b101};
      bins bltu = {3'b110};
      bins bgeu = {3'b111};
    }
    jal_seen: coverpoint (item.insn[1:0] == 2'b11 && item.insn[6:0] == 7'b1101111);
    jalr_seen: coverpoint (item.insn[1:0] == 2'b11 && item.insn[6:0] == 7'b1100111);
    pc_delta: coverpoint pc_delta_kind(item.pc_rdata, item.pc_wdata) iff (is_branch_or_jump(item.insn)) {
      bins not_taken_seq32 = {0};
      bins not_taken_seq16 = {1};
      bins backward = {2};
      bins forward = {3};
      bins same_or_other = {4};
    }
    compressed_control: coverpoint (item.insn[1:0] != 2'b11) iff
      (item.insn[15:13] == 3'b001 || item.insn[15:13] == 3'b101 ||
       item.insn[15:13] == 3'b110 || item.insn[15:13] == 3'b111);
    branch_x_delta: cross branch_type, pc_delta;
  endgroup

  covergroup csr_priv_cg with function sample(ibex_rvfi_item item);
    option.per_instance = 1;
    csr_op: coverpoint item.insn[14:12] iff (is_csr(item.insn)) {
      bins csrrw = {3'b001};
      bins csrrs = {3'b010};
      bins csrrc = {3'b011};
      bins csrrwi = {3'b101};
      bins csrrsi = {3'b110};
      bins csrrci = {3'b111};
    }
    csr_imm: coverpoint item.insn[14] iff (is_csr(item.insn));
    system_kind: coverpoint system_instr_kind(item.insn) {
      bins ecall = {1};
      bins ebreak = {2};
      bins mret = {3};
      bins wfi = {4};
      bins dret = {5};
      bins csr = {6};
    }
    mode: coverpoint item.mode {
      bins user = {2'b00};
      bins machine = {2'b11};
    }
    trap: coverpoint item.trap;
    csr_x_mode: cross csr_op, mode;
  endgroup

  covergroup interrupt_debug_cg with function sample(bit sw_irq, bit timer_irq,
                                                     bit external_irq, bit fast_irq,
                                                     bit nmi_irq, bit intr_entry,
                                                     bit mret_seen,
                                                     bit debug_req_seen,
                                                     bit debug_entry_seen,
                                                     bit dret_seen);
    option.per_instance = 1;
    software_interrupt: coverpoint sw_irq;
    timer_interrupt: coverpoint timer_irq;
    external_interrupt: coverpoint external_irq;
    fast_interrupt: coverpoint fast_irq;
    nmi_interrupt: coverpoint nmi_irq;
    interrupt_trap_entry: coverpoint intr_entry;
    interrupt_mret: coverpoint (intr_entry && mret_seen);
    debug_request_pulse: coverpoint debug_req_seen;
    debug_entry: coverpoint debug_entry_seen;
    dret: coverpoint dret_seen;
  endgroup

  covergroup pipeline_hazard_cg with function sample(ibex_rvfi_item item,
                                                     bit b2b_alu_dep,
                                                     bit load_use_dep,
                                                     bit store_after_alu_dep,
                                                     bit branch_after_alu_dep,
                                                     bit b2b_branch_jump,
                                                     bit b2b_load_store);
    option.per_instance = 1;
    back_to_back_alu_dependency: coverpoint b2b_alu_dep;
    load_use_dependency: coverpoint load_use_dep;
    store_after_alu_dependency: coverpoint store_after_alu_dep;
    branch_after_alu_dependency: coverpoint branch_after_alu_dep;
    back_to_back_branch_jump: coverpoint b2b_branch_jump;
    back_to_back_load_store: coverpoint b2b_load_store;
    pc_delta: coverpoint pc_delta_kind(item.pc_rdata, item.pc_wdata) {
      bins sequential_32b = {0};
      bins sequential_16b = {1};
      bins nonseq_backward = {2};
      bins nonseq_forward = {3};
      bins same_or_other = {4};
    }
    dependency_x_pc_delta: cross load_use_dependency, branch_after_alu_dependency, pc_delta;
  endgroup

  covergroup irq_cg with function sample(ibex_irq_item item);
    option.per_instance = 1;
    sw: coverpoint item.irq_software;
    timer: coverpoint item.irq_timer;
    external_irq: coverpoint item.irq_external;
    fast: coverpoint (|item.irq_fast);
    fast_id: coverpoint item.irq_fast {
      bins fast_irq_lines[] = {
        15'b000000000000001, 15'b000000000000010, 15'b000000000000100,
        15'b000000000001000, 15'b000000000010000, 15'b000000000100000,
        15'b000000001000000, 15'b000000010000000, 15'b000000100000000,
        15'b000001000000000, 15'b000010000000000, 15'b000100000000000,
        15'b001000000000000, 15'b010000000000000, 15'b100000000000000
      };
    }
    nmi: coverpoint item.irq_nm;
    any_irq: coverpoint (item.irq_software || item.irq_timer || item.irq_external ||
                         (|item.irq_fast) || item.irq_nm);
    irq_type_cross: cross sw, timer, external_irq, fast, nmi;
  endgroup

  covergroup ctrl_cg with function sample(ibex_ctrl_item item);
    option.per_instance = 1;
    reset_state: coverpoint item.rst_n {
      bins asserted = {0};
      bins deasserted = {1};
    }
    debug_req: coverpoint item.debug_req;
    fetch_enable: coverpoint item.fetch_enable {
      bins default_fetch = {4'b0101};
      bins disabled = {4'b0000};
      bins other = default;
    }
    mcounteren_writable: coverpoint item.mcounteren_writable {
      bins default_mcounteren = {4'b0101};
      bins none = {4'b0000};
      bins all = {4'b1111};
      bins other = default;
    }
    reset_x_debug: cross reset_state, debug_req;
  endgroup

  covergroup vplan_cg;
    option.per_instance = 1;
    f001_reset_bootstrap: coverpoint hit_f001_reset_bootstrap { bins hit = {1}; }
    f002_imem_protocol: coverpoint hit_f002_imem_protocol { bins hit = {1}; }
    f003_dmem_load_store: coverpoint hit_f003_dmem_load_store { bins hit = {1}; }
    f004_rv32i_alu: coverpoint hit_f004_rv32i_alu { bins hit = {1}; }
    f005_m_extension: coverpoint hit_f005_m_extension { bins hit = {1}; }
    f006_c_extension: coverpoint hit_f006_c_extension { bins hit = {1}; }
    f007_branch_jump: coverpoint hit_f007_branch_jump { bins hit = {1}; }
    f008_trap_exception: coverpoint hit_f008_trap_exception { bins hit = {1}; }
    f009_interrupt: coverpoint hit_f009_interrupt { bins hit = {1}; }
    f010_csr_privilege: coverpoint hit_f010_csr_privilege { bins hit = {1}; }
    f011_memory_backpressure: coverpoint hit_f011_memory_backpressure { bins hit = {1}; }
    f012_reset_active_transfer: coverpoint hit_f012_reset_active_transfer { bins hit = {1}; }
    f013_debug_request: coverpoint hit_f013_debug_request { bins hit = {1}; }
    f014_random_isa_stream: coverpoint hit_f014_random_isa_stream { bins hit = {1}; }
    f015_arch_equivalence: coverpoint hit_f015_arch_equivalence { bins hit = {1}; }
  endgroup

  `uvm_component_utils(ibex_coverage_collector)

  function new(string name, uvm_component parent);
    super.new(name, parent);
    dmem_export = new("dmem_export", this);
    imem_export = new("imem_export", this);
    rvfi_export = new("rvfi_export", this);
    irq_export = new("irq_export", this);
    ctrl_export = new("ctrl_export", this);
    rvfi_cg = new();
    mem_cg = new();
    single_instr_cg = new();
    exception_illegal_cg = new();
    lsu_corner_cg = new();
    branch_jump_cg = new();
    csr_priv_cg = new();
    interrupt_debug_cg = new();
    pipeline_hazard_cg = new();
    irq_cg = new();
    ctrl_cg = new();
    vplan_cg = new();
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    if (!uvm_config_db#(ibex_env_cfg)::get(this, "", "cfg", cfg))
      `uvm_fatal(get_full_name(), "Missing environment cfg")
  endfunction

  function void write_cov_dmem(ibex_mem_txn item);
    saw_activity_before_reset = 1'b1;
    if (item.we) seen_dmem_store = 1'b1;
    else seen_dmem_load = 1'b1;
    hit_f003_dmem_load_store = seen_dmem_load && seen_dmem_store;
    if (item.response_latency > 1) hit_f011_memory_backpressure = 1'b1;
    mem_cg.sample(item, 1'b1);
    lsu_corner_cg.sample(item, 1'b1);
  endfunction

  function void write_cov_imem(ibex_mem_txn item);
    saw_activity_before_reset = 1'b1;
    hit_f002_imem_protocol = 1'b1;
    if (item.response_latency > 1) hit_f011_memory_backpressure = 1'b1;
    mem_cg.sample(item, 1'b0);
    lsu_corner_cg.sample(item, 1'b0);
  endfunction

  function void write_cov_rvfi(ibex_rvfi_item item);
    bit b2b_alu_dep;
    bit load_use_dep;
    bit store_after_alu_dep;
    bit branch_after_alu_dep;
    bit b2b_branch_jump;
    bit b2b_load_store;
    if (item.irq_only) begin
      seen_irq_trap = 1'b1;
      hit_f009_interrupt = 1'b1;
      interrupt_debug_cg.sample(seen_irq_pulse, 1'b0, 1'b0, 1'b0, 1'b0,
                                seen_irq_trap, seen_mret,
                                seen_debug_req_pulse, seen_debug_entry, 1'b0);
      return;
    end

    saw_activity_before_reset = 1'b1;
    observed_opcode_classes[opcode_class(item.insn)] = 1'b1;
    if (!first_retire_seen) begin
      first_retire_seen = 1'b1;
      if (saw_reset_deasserted && item.pc_rdata == cfg.start_pc)
        hit_f001_reset_bootstrap = 1'b1;
    end
    if (is_rv32i_alu(item.insn)) begin
      observed_alu_funct3[item.insn[14:12]] = 1'b1;
      hit_f004_rv32i_alu = (observed_alu_funct3[0] && observed_alu_funct3[4] &&
                            observed_alu_funct3[6] && observed_alu_funct3[7]);
    end
    if (is_m_extension(item.insn)) hit_f005_m_extension = 1'b1;
    if (item.insn[1:0] != 2'b11) hit_f006_c_extension = 1'b1;
    if (is_branch(item.insn)) seen_branch = 1'b1;
    if (is_jump(item.insn)) seen_jump = 1'b1;
    hit_f007_branch_jump = seen_branch && seen_jump;
    if (item.trap || system_instr_kind(item.insn) inside {[1:5]})
      hit_f008_trap_exception = 1'b1;
    if (item.intr) begin
      seen_irq_trap = 1'b1;
      hit_f009_interrupt = seen_irq_pulse;
    end
    if (is_csr(item.insn)) seen_csr_op = 1'b1;
    if (system_instr_kind(item.insn) == 3) seen_mret = 1'b1;
    hit_f010_csr_privilege = seen_csr_op && (seen_mret || item.trap);
    if (item.debug_mode || item.halt) seen_debug_entry = 1'b1;
    if (seen_debug_req_pulse && seen_debug_entry) hit_f013_debug_request = 1'b1;
    if (count_opcode_classes() >= 6) hit_f014_random_isa_stream = 1'b1;
    hit_f015_arch_equivalence = 1'b1;

    b2b_alu_dep = have_last_rvfi && last_was_alu && is_rv32i_alu(item.insn) &&
                  (has_rs1_dep(item) || has_rs2_dep(item));
    load_use_dep = have_last_rvfi && last_was_load && (has_rs1_dep(item) || has_rs2_dep(item));
    store_after_alu_dep = have_last_rvfi && last_was_alu && is_store(item.insn) &&
                          (has_rs1_dep(item) || has_rs2_dep(item));
    branch_after_alu_dep = have_last_rvfi && last_was_alu && is_branch(item.insn) &&
                           (has_rs1_dep(item) || has_rs2_dep(item));
    b2b_branch_jump = have_last_rvfi && last_was_branch_jump && is_branch_or_jump(item.insn);
    b2b_load_store = have_last_rvfi && (last_was_load || last_was_store) &&
                     (is_load(item.insn) || is_store(item.insn));

    rvfi_cg.sample(item);
    single_instr_cg.sample(item);
    exception_illegal_cg.sample(item);
    branch_jump_cg.sample(item);
    csr_priv_cg.sample(item);
    interrupt_debug_cg.sample(seen_irq_pulse, 1'b0, 1'b0, 1'b0, 1'b0,
                              seen_irq_trap || item.intr, seen_mret,
                              seen_debug_req_pulse, seen_debug_entry,
                              system_instr_kind(item.insn) == 5);
    pipeline_hazard_cg.sample(item, b2b_alu_dep, load_use_dep, store_after_alu_dep,
                              branch_after_alu_dep, b2b_branch_jump, b2b_load_store);

    have_last_rvfi = 1'b1;
    last_insn = item.insn;
    last_rd = item.rd_addr;
    last_has_rd = item.rd_addr != 0 && !item.rf_wr_suppress;
    last_was_alu = is_rv32i_alu(item.insn);
    last_was_load = is_load(item.insn);
    last_was_store = is_store(item.insn);
    last_was_branch_jump = is_branch_or_jump(item.insn);
  endfunction

  function void write_cov_irq(ibex_irq_item item);
    if (item.irq_software || item.irq_timer || item.irq_external ||
        (|item.irq_fast) || item.irq_nm) seen_irq_pulse = 1'b1;
    hit_f009_interrupt = seen_irq_pulse && seen_irq_trap;
    irq_cg.sample(item);
    interrupt_debug_cg.sample(item.irq_software, item.irq_timer, item.irq_external,
                              |item.irq_fast, item.irq_nm, seen_irq_trap, seen_mret,
                              seen_debug_req_pulse, seen_debug_entry, 1'b0);
  endfunction

  function void write_cov_ctrl(ibex_ctrl_item item);
    if (!item.rst_n) begin
      saw_reset_asserted = 1'b1;
      if (saw_activity_before_reset) hit_f012_reset_active_transfer = 1'b1;
    end
    if (item.rst_n && saw_reset_asserted) saw_reset_deasserted = 1'b1;
    if (item.debug_req) seen_debug_req_pulse = 1'b1;
    if (seen_debug_req_pulse && seen_debug_entry) hit_f013_debug_request = 1'b1;
    ctrl_cg.sample(item);
  endfunction

  function void report_phase(uvm_phase phase);
    super.report_phase(phase);
    vplan_cg.sample();
    `uvm_info(get_full_name(), $sformatf(
      "Functional coverage: VPLAN=%0.2f%% RVFI=%0.2f%% MEM=%0.2f%% IRQ=%0.2f%% CTRL=%0.2f%% USER_GROUPS={SINGLE=%0.2f%% EXC=%0.2f%% LSU=%0.2f%% BR=%0.2f%% CSR=%0.2f%% IRQDBG=%0.2f%% PIPE=%0.2f%%}",
      vplan_cg.get_inst_coverage(), rvfi_cg.get_inst_coverage(),
      mem_cg.get_inst_coverage(), irq_cg.get_inst_coverage(),
      ctrl_cg.get_inst_coverage(), single_instr_cg.get_inst_coverage(),
      exception_illegal_cg.get_inst_coverage(), lsu_corner_cg.get_inst_coverage(),
      branch_jump_cg.get_inst_coverage(), csr_priv_cg.get_inst_coverage(),
      interrupt_debug_cg.get_inst_coverage(), pipeline_hazard_cg.get_inst_coverage()), UVM_NONE)
  endfunction
endclass

