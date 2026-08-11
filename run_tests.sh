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

run_cpu_test() {
  run_test tb_CPU_Top \
    rtl/Controller.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    rtl/CPU_Top.sv \
    rtl/EXWB.sv \
    rtl/IDEX.sv \
    rtl/IFID.sv \
    rtl/Inst_Decoder.sv \
    rtl/PC.sv \
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
    run_store_test
    run_load_test
    run_load_hazard_test
    run_hazard_test
    run_cpu_test
    run_branch_test
    run_jal_test
    run_jalr_test
    echo "Waveform: ${build_dir}/cpu_top.vcd"
    ;;

  *)
    echo "Unknown test: ${test_name}" >&2
    echo "Usage: $0 {pc|reg|instdecoder|ifid|idex|exwb|alu|control|forwarding|hazardunit|branchunit|memory|storeunit|loadunit|store|load|loadhazard|hazard|cpu|branch|jal|jalr|all}" >&2
    exit 1
    ;;
esac
