#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
elf_dir="${ACT4_ELF_DIR:-${project_dir}/build/arch-test/act4/cpu-build-rv32i/elfs/rv32i/I}"
output_dir="${project_dir}/build/arch-test/rtl"
simulation="${output_dir}/tb_ACT4"
selector="${1:-*.elf}"
max_cycles="${ACT4_MAX_CYCLES:-2000000}"

mkdir -p "${output_dir}/images" "${output_dir}/logs"

sources=(
  rtl/Trap_Detect.sv rtl/Trap_Unit.sv rtl/Arch_Test_Memory.sv
  rtl/Controller.sv rtl/CPU_Core.sv rtl/CPU_Sim_Top.sv rtl/EXWB.sv
  rtl/IDEX.sv rtl/IFID.sv rtl/Inst_Decoder.sv rtl/PC.sv
  rtl/Program_ROM.sv rtl/Reg_File.sv rtl/Control_Unit.sv rtl/ALU.sv
  rtl/Forwarding_Unit.sv rtl/Hazard_Unit.sv rtl/Branch_Unit.sv
  rtl/Store_Unit.sv rtl/Data_Memory.sv rtl/Load_Unit.sv tb/tb_ACT4.sv
)

cd "${project_dir}"
echo "[COMPILE] ACT4 RTL adapter"
iverilog -g2012 -Wall -Wimplicit -I rtl -s tb_ACT4 -o "${simulation}" "${sources[@]}"

shopt -s nullglob
elfs=("${elf_dir}"/${selector})
if ((${#elfs[@]} == 0)); then
  echo "error: no ACT4 ELF matched ${elf_dir}/${selector}" >&2
  exit 1
fi

passed=0
failed=0
failed_names=()
for elf in "${elfs[@]}"; do
  name="$(basename "${elf}" .elf)"
  image="${output_dir}/images/${name}.hex"
  log="${output_dir}/logs/${name}.log"
  python3 tools/elf_to_sparse_hex.py "${elf}" "${image}" >/dev/null
  echo "[RUN]     ${name}"
  if vvp "${simulation}" "+MEM_HEX=${image}" "+TEST_NAME=${name}" "+MAX_CYCLES=${max_cycles}" >"${log}" 2>&1; then
    tail -n 1 "${log}"
    passed=$((passed + 1))
  else
    cat "${log}"
    failed=$((failed + 1))
    failed_names+=("${name}")
  fi
done

echo "[SUMMARY] passed=${passed} failed=${failed} total=$((passed + failed))"
if ((failed != 0)); then
  printf '[FAILED]  %s\n' "${failed_names[*]}" >&2
  exit 1
fi
