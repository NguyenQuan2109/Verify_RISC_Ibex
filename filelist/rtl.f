// Ibex RTL and lowRISC primitive dependencies.
// Set PRJ_DIR to this repository's absolute path before compiling.

+incdir+${PRJ_DIR}/dut/ip/prim/rtl
+incdir+${PRJ_DIR}/dut/ip/dv/sv/dv_utils
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_assert.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_util_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_count_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_count.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_22_16_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_22_16_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_64_57_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_64_57_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_22_16_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_22_16_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_39_32_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_39_32_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_72_64_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_hamming_72_64_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_mubi_pkg.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_ram_1p_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_ram_1p_adv.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_ram_1p_scr.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_ram_1p.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_clock_gating.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_buf.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_clock_mux2.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_flop.sv
${PRJ_DIR}/dut/ip/prim_generic/rtl/prim_and2.sv

// Shared lowRISC code
${PRJ_DIR}/dut/ip/prim/rtl/prim_cipher_pkg.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_lfsr.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_28_22_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_28_22_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_39_32_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_39_32_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_72_64_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_inv_72_64_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_prince.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_subst_perm.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_28_22_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_28_22_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_39_32_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_39_32_dec.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_72_64_enc.sv
${PRJ_DIR}/dut/ip/prim/rtl/prim_secded_72_64_dec.sv

// ibex CORE RTL files
+incdir+${PRJ_DIR}/dut/rtl
${PRJ_DIR}/dut/rtl/ibex_pkg.sv
${PRJ_DIR}/dut/rtl/ibex_tracer_pkg.sv
${PRJ_DIR}/dut/rtl/ibex_tracer.sv
${PRJ_DIR}/dut/rtl/ibex_alu.sv
${PRJ_DIR}/dut/rtl/ibex_branch_predict.sv
${PRJ_DIR}/dut/rtl/ibex_compressed_decoder.sv
${PRJ_DIR}/dut/rtl/ibex_controller.sv
${PRJ_DIR}/dut/rtl/ibex_csr.sv
${PRJ_DIR}/dut/rtl/ibex_cs_registers.sv
${PRJ_DIR}/dut/rtl/ibex_counter.sv
${PRJ_DIR}/dut/rtl/ibex_decoder.sv
${PRJ_DIR}/dut/rtl/ibex_dummy_instr.sv
${PRJ_DIR}/dut/rtl/ibex_ex_block.sv
${PRJ_DIR}/dut/rtl/ibex_wb_stage.sv
${PRJ_DIR}/dut/rtl/ibex_id_stage.sv
${PRJ_DIR}/dut/rtl/ibex_icache.sv
${PRJ_DIR}/dut/rtl/ibex_if_stage.sv
${PRJ_DIR}/dut/rtl/ibex_load_store_unit.sv
${PRJ_DIR}/dut/rtl/ibex_lockstep.sv
${PRJ_DIR}/dut/rtl/ibex_multdiv_slow.sv
${PRJ_DIR}/dut/rtl/ibex_multdiv_fast.sv
${PRJ_DIR}/dut/rtl/ibex_prefetch_buffer.sv
${PRJ_DIR}/dut/rtl/ibex_fetch_fifo.sv
${PRJ_DIR}/dut/rtl/ibex_register_file_ff.sv
${PRJ_DIR}/dut/rtl/ibex_register_file_fpga.sv
${PRJ_DIR}/dut/rtl/ibex_register_file_latch.sv
${PRJ_DIR}/dut/rtl/ibex_pmp.sv
${PRJ_DIR}/dut/rtl/ibex_core.sv
${PRJ_DIR}/dut/rtl/ibex_top.sv
${PRJ_DIR}/dut/rtl/ibex_top_tracing.sv

