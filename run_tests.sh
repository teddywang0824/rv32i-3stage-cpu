#!/usr/bin/env bash

set -euo pipefail

# 錯誤處理設定：
# -e：任何指令執行失敗時，立即停止腳本。
# -u：使用尚未定義的變數時，立即報錯。
# -o pipefail：管線中只要有任一指令失敗，整個管線就視為失敗。

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
rtl_dir="${project_dir}/rtl"
build_dir="${project_dir}/build"

mkdir -p "${build_dir}"
cd "${project_dir}"

run_test() {
  local top="$1"
  shift

  local simulation="${build_dir}/${top}"

  echo "[COMPILE] ${top}"

  iverilog \
    -g2012 \
    -Wall \
    -Wimplicit \
    -I "${rtl_dir}" \
    -s "${top}" \
    -o "${simulation}" \
    rtl/Trap_Detect.sv \
    rtl/Trap_Unit.sv \
    rtl/Arch_Test_Memory.sv \
    "$@"

  echo "[RUN]     ${top}"
  vvp "${simulation}"

  echo
}

run_pc_test() {
  run_test tb_PC \
    rtl/PC.sv \
    tb/tb_PC.sv
}

run_reg_test() {
  run_test tb_Reg_File \
    rtl/Reg_File.sv \
    tb/tb_Reg_File.sv
}

run_inst_decoder_test() {
  run_test tb_Inst_Decoder \
    rtl/Inst_Decoder.sv \
    tb/tb_Inst_Decoder.sv
}

run_program_rom_test() {
  run_test tb_Program_ROM \
    rtl/Program_ROM.sv \
    tb/tb_Program_ROM.sv
}

run_ifid_test() {
  run_test tb_IFID \
    rtl/IFID.sv \
    tb/tb_IFID.sv
}

run_idex_test() {
  run_test tb_IDEX \
    rtl/IDEX.sv \
    tb/tb_IDEX.sv
}

run_exwb_test() {
  run_test tb_EXWB \
    rtl/EXWB.sv \
    tb/tb_EXWB.sv
}

run_alu_test() {
  run_test tb_ALU \
    rtl/ALU.sv \
    tb/tb_ALU.sv
}

run_control_test() {
  run_test tb_Control_Unit \
    rtl/Control_Unit.sv \
    tb/tb_Control_Unit.sv
}

run_forwarding_test() {
  run_test tb_Forwarding_Unit \
    rtl/Forwarding_Unit.sv \
    tb/tb_Forwarding_Unit.sv
}

run_hazard_unit_test() {
  run_test tb_Hazard_Unit \
    rtl/Hazard_Unit.sv \
    tb/tb_Hazard_Unit.sv
}

run_branch_unit_test() {
  run_test tb_Branch_Unit \
    rtl/Branch_Unit.sv \
    tb/tb_Branch_Unit.sv
}

run_data_memory_test() {
  run_test tb_Data_Memory \
    rtl/Data_Memory.sv \
    tb/tb_Data_Memory.sv
}

run_store_unit_test() {
  run_test tb_Store_Unit \
    rtl/Store_Unit.sv \
    tb/tb_Store_Unit.sv
}

run_load_unit_test() {
  run_test tb_Load_Unit \
    rtl/Load_Unit.sv \
    tb/tb_Load_Unit.sv
}

run_trap_detect_test() {
  run_test tb_Trap_Detect \
    tb/tb_Trap_Detect.sv
}

run_trap_unit_test() {
  run_test tb_Trap_Unit \
    tb/tb_Trap_Unit.sv
}

run_cpu_trap_test() {
  run_test tb_CPU_Trap \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Trap.sv
}

run_cpu_fence_test() {
  run_test tb_CPU_FENCE \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_FENCE.sv
}

run_cpu_system_test() {
  run_test tb_CPU_SYSTEM \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_SYSTEM.sv
}

run_cpu_alignment_test() {
  run_test tb_CPU_Alignment \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Alignment.sv
}

run_image_tool_tests() {
  echo "[HOST TEST] bin_to_word_hex.py"
  python3 tools/test_bin_to_word_hex.py
  echo
}

run_cpu_image_test() {
  ./build_program.sh programs/image_smoke.S
  python3 tools/verify_image_smoke.py build/programs/image_smoke

  run_test tb_CPU_Image \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Image.sv
}

run_rv32i_directed_test() {
  echo "[MATRIX]  RV32I base 40 traceability"
  python3 tools/check_rv32i_matrix.py
  echo

  ./build_program.sh programs/rv32i_directed.S
  python3 tools/verify_rv32i_directed.py

  run_test tb_CPU_Directed \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv \
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Directed.sv
}

run_arch_test() {
  bash verification/arch-test/run_arch_tests.sh "${1:-*.elf}"
}

run_compiled_program_test() {
  local output_dir="build/programs/compiled_workloads"
  local elf_file="${output_dir}/compiled_workloads.elf"
  local dump_file="${output_dir}/compiled_workloads.dump"
  local symbols_file="${output_dir}/compiled_workloads.symbols.txt"
  local tool_prefix="${RISCV_PREFIX:-/opt/riscv/gcc-15.2.0/bin/riscv-none-elf-}"

  mkdir -p "${output_dir}"
  echo "[BUILD]   representative freestanding C program"
  "${tool_prefix}gcc" \
    -march=rv32i -mabi=ilp32 -O1 \
    -ffreestanding -fno-builtin -fno-stack-protector -fno-pic \
    -nostdlib -nostartfiles -mno-relax \
    -Wl,--build-id=none -Wl,--no-relax -Wl,--no-warn-rwx-segments \
    -Wl,-T,verification/arch-test/link.ld \
    -Wl,-Map,"${output_dir}/compiled_workloads.map" \
    -o "${elf_file}" \
    programs/compiled_startup.S programs/compiled_workloads.c

  "${tool_prefix}objdump" -d -M no-aliases,numeric "${elf_file}" > "${dump_file}"
  "${tool_prefix}nm" -n "${elf_file}" > "${symbols_file}"
  if "${tool_prefix}nm" -u "${elf_file}" | grep -q .; then
    echo "[FAIL] compiled workload has unresolved runtime symbols" >&2
    "${tool_prefix}nm" -u "${elf_file}" >&2
    return 1
  fi
  if grep -Eq $'\\t(c\\.|mul|mulh|mulhsu|mulhu|div|divu|rem|remu|csrr|csrw|mret|wfi)' "${dump_file}"; then
    echo "[FAIL] compiled workload contains an unsupported instruction" >&2
    return 1
  fi

  local first_result second_result
  first_result="$(ACT4_ELF_DIR="${project_dir}/${output_dir}" \
    bash verification/arch-test/run_arch_tests.sh compiled_workloads.elf \
    | tee "${output_dir}/run-1.txt" | grep '\[ACT4 PASS\]')"
  second_result="$(ACT4_ELF_DIR="${project_dir}/${output_dir}" \
    bash verification/arch-test/run_arch_tests.sh compiled_workloads.elf \
    | tee "${output_dir}/run-2.txt" | grep '\[ACT4 PASS\]')"
  echo "${first_result}"
  echo "${second_result}"
  if [[ "${first_result}" != "${second_result}" ]]; then
    echo "[FAIL] compiled workload is not cycle/retire deterministic" >&2
    return 1
  fi
  echo "[PASS] compiled workload: call/return, stack, .data/.bss, copy, and branch loop"
}

run_cpu_test() {
  run_test tb_CPU_Top \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Top.sv
}

run_hazard_test() {
  run_test tb_Hazard_Observe \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_Hazard_Observe.sv
}

run_branch_test() {
  run_test tb_CPU_Branch \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Branch.sv
}

run_jal_test() {
  run_test tb_CPU_JAL \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_JAL.sv
}

run_jalr_test() {
  run_test tb_CPU_JALR \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_JALR.sv
}

run_store_test() {
  run_test tb_CPU_Store \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Store.sv
}

run_load_test() {
  run_test tb_CPU_Load \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Load.sv
}

run_load_hazard_test() {
  run_test tb_CPU_Load_Hazard \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Load_Hazard.sv
}

run_illegal_test() {
  run_test tb_CPU_Illegal \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Illegal.sv
}

run_program_test() {
  run_test tb_CPU_Program \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Program.sv
}

run_retire_test() {
  run_test tb_CPU_Retire \
    rtl/Controller.sv \
    rtl/CPU_Core.sv \
    rtl/CPU_Sim_Top.sv \
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
    rtl/Program_ROM.sv \
    rtl/Reg_File.sv \
    rtl/Control_Unit.sv \
    rtl/ALU.sv \
    rtl/Forwarding_Unit.sv\
    rtl/Hazard_Unit.sv \
    rtl/Branch_Unit.sv \
    rtl/Store_Unit.sv \
    rtl/Data_Memory.sv \
    rtl/Load_Unit.sv \
    tb/tb_CPU_Retire.sv
}

test_name="${1:-all}"

case "${test_name}" in
  pc)
    run_pc_test
    ;;

  reg)
    run_reg_test
    ;;

  instdecoder)
    run_inst_decoder_test
    ;;

  programrom)
    run_program_rom_test
    ;;
  
  ifid)
    run_ifid_test
    ;;

  idex)
    run_idex_test
    ;;

  exwb)
    run_exwb_test
    ;;

  alu)
    run_alu_test
    ;;

  control)
    run_control_test
    ;;

  forwarding)
    run_forwarding_test
    ;;

  hazardunit)
    run_hazard_unit_test
    ;;

  branchunit)
    run_branch_unit_test
    ;;

  memory)
    run_data_memory_test
    ;;

  storeunit)
    run_store_unit_test
    ;;

  loadunit)
    run_load_unit_test
    ;;

  trapdetect)
    run_trap_detect_test
    ;;

  trapunit)
    run_trap_unit_test
    ;;

  cputrap)
    run_cpu_trap_test
    ;;

  fence)
    run_cpu_fence_test
    ;;

  system)
    run_cpu_system_test
    ;;

  alignment)
    run_cpu_alignment_test
    ;;

  imagetools)
    run_image_tool_tests
    ;;

  image)
    run_image_tool_tests
    run_cpu_image_test
    ;;

  directed)
    run_rv32i_directed_test
    ;;

  arch)
    run_arch_test
    ;;

  compiled)
    run_compiled_program_test
    ;;

  store)
    run_store_test
    echo "Waveform: ${build_dir}/cpu_store.vcd"
    ;;

  load)
    run_load_test
    echo "Waveform: ${build_dir}/cpu_load.vcd"
    ;;

  loadhazard)
    run_load_hazard_test
    echo "Waveform: ${build_dir}/cpu_load_hazard.vcd"
    ;;

  illegal)
    run_illegal_test
    echo "Waveform: ${build_dir}/cpu_illegal.vcd"
    ;;

  program)
    run_program_test
    echo "Waveform: ${build_dir}/cpu_program.vcd"
    ;;

  retire)
    run_retire_test
    echo "Waveform: ${build_dir}/cpu_retire.vcd"
    ;;

  branch)
    run_branch_test
    echo "Waveform: ${build_dir}/cpu_branch.vcd"
    ;;

  jal)
    run_jal_test
    echo "Waveform: ${build_dir}/cpu_jal.vcd"
    ;;

  jalr)
    run_jalr_test
    echo "Waveform: ${build_dir}/cpu_jalr.vcd"
    ;;

  hazard)
    run_hazard_test
    echo "Waveform: ${build_dir}/hazard_observe.vcd"
    ;;

  cpu)
    run_cpu_test
    echo "Waveform: ${build_dir}/cpu_top.vcd"
    ;;

  all)
    run_pc_test
    run_reg_test
    run_inst_decoder_test
    run_program_rom_test
    run_ifid_test
    run_idex_test
    run_exwb_test
    run_alu_test
    run_control_test
    run_forwarding_test
    run_hazard_unit_test
    run_branch_unit_test
    run_data_memory_test
    run_store_unit_test
    run_load_unit_test
    run_trap_detect_test
    run_trap_unit_test
    run_cpu_trap_test
    run_cpu_fence_test
    run_cpu_system_test
    run_cpu_alignment_test
    run_image_tool_tests
    run_cpu_image_test
    run_rv32i_directed_test
    run_arch_test
    run_compiled_program_test
    run_store_test
    run_load_test
    run_load_hazard_test
    run_illegal_test
    run_program_test
    run_retire_test
    run_hazard_test
    run_cpu_test
    run_branch_test
    run_jal_test
    run_jalr_test
    echo "Waveform: ${build_dir}/cpu_top.vcd"
    ;;

  *)
    echo "Unknown test: ${test_name}" >&2
    echo "Usage: $0 {pc|reg|instdecoder|programrom|ifid|idex|exwb|alu|control|forwarding|hazardunit|branchunit|memory|storeunit|loadunit|trapdetect|trapunit|cputrap|fence|system|alignment|imagetools|image|directed|arch|compiled|store|load|loadhazard|illegal|program|retire|hazard|cpu|branch|jal|jalr|all}" >&2
    exit 1
    ;;
esac
