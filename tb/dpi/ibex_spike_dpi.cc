// SPDX-License-Identifier: Apache-2.0
// Standalone initialization wrapper around lowRISC's SpikeCosim C++ model.

#include <svdpi.h>

#include <cassert>
#include <string>

#include "cosim.h"
#include "spike_cosim.h"

extern "C" {

void *ibex_spike_cosim_init(const char *isa_string, svBitVecVal *start_pc,
                            svBitVecVal *start_mtvec,
                            const char *log_file_path,
                            svBitVecVal *pmp_num_regions,
                            svBitVecVal *pmp_granularity,
                            svBitVecVal *mhpm_counter_num,
                            svBit secure_ibex, svBit icache,
                            svBitVecVal *dm_start_addr,
                            svBitVecVal *dm_end_addr) {
  assert(isa_string != nullptr);
  const std::string log_path = log_file_path ? log_file_path : "";
  auto *cosim = new SpikeCosim(
      isa_string, start_pc[0], start_mtvec[0], log_path,
      secure_ibex != 0, icache != 0, pmp_num_regions[0],
      pmp_granularity[0], mhpm_counter_num[0], dm_start_addr[0],
      dm_end_addr[0]);
  cosim->add_memory(0x00000000, 0xFFFF0000);
  return static_cast<Cosim *>(cosim);
}

void ibex_spike_cosim_release(void *cosim_handle) {
  delete static_cast<Cosim *>(cosim_handle);
}

}  // extern "C"
