#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "${project_dir}"

verilator_bin="${VERILATOR_BIN:-}"
if [[ -z "${verilator_bin}" ]]; then
  if command -v verilator >/dev/null 2>&1; then
    verilator_bin="$(command -v verilator)"
  elif [[ -x /home/yuan/.local/opt/verilator-4.038/usr/bin/verilator_bin ]]; then
    verilator_bin=/home/yuan/.local/opt/verilator-4.038/usr/bin/verilator_bin
  else
    echo "error: Verilator not found; set VERILATOR_BIN=/path/to/verilator" >&2
    exit 1
  fi
fi

sources=(
  rtl/CPU_Core.sv rtl/Controller.sv rtl/PC.sv rtl/Inst_Decoder.sv
  rtl/Reg_File.sv rtl/Control_Unit.sv rtl/IDEX.sv rtl/EXWB.sv
  rtl/ALU.sv rtl/Forwarding_Unit.sv rtl/Hazard_Unit.sv
  rtl/Branch_Unit.sv rtl/Store_Unit.sv rtl/Load_Unit.sv
  rtl/Trap_Detect.sv rtl/Trap_Unit.sv
)

echo "[LINT]    CPU_Core synthesizable hierarchy"
"${verilator_bin}" \
  --lint-only --sv --top-module CPU_Core -Irtl -Wall \
  "${sources[@]}"
echo "[PASS]    Verilator lint completed with zero diagnostics"
