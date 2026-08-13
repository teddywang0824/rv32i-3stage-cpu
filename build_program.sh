#!/usr/bin/env bash

set -euo pipefail

project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${project_dir}"

source_file="${1:-programs/image_smoke.S}"
linker_script="${2:-programs/link.ld}"

source_name="$(basename "${source_file}")"
program_name="${source_name%.*}"
output_dir="build/programs/${program_name}"

elf_file="${output_dir}/${program_name}.elf"
map_file="${output_dir}/${program_name}.map"
dump_file="${output_dir}/${program_name}.dump"
sections_file="${output_dir}/${program_name}.sections.txt"
symbols_file="${output_dir}/${program_name}.symbols.txt"
imem_bin="${output_dir}/${program_name}_imem.bin"
dmem_bin="${output_dir}/${program_name}_dmem.bin"
imem_hex="${output_dir}/${program_name}_imem.hex"
dmem_hex="${output_dir}/${program_name}_dmem.hex"

required_tools=(
  riscv64-unknown-elf-gcc
  riscv64-unknown-elf-objcopy
  riscv64-unknown-elf-objdump
  riscv64-unknown-elf-readelf
  riscv64-unknown-elf-nm
  python3
)

for tool in "${required_tools[@]}"; do
  if ! command -v "${tool}" >/dev/null 2>&1; then
    echo "error: required tool not found: ${tool}" >&2
    exit 1
  fi
done

if [[ ! -f "${source_file}" ]]; then
  echo "error: assembly source not found: ${source_file}" >&2
  exit 1
fi

if [[ ! -f "${linker_script}" ]]; then
  echo "error: linker script not found: ${linker_script}" >&2
  exit 1
fi

if [[ ! -f tools/bin_to_word_hex.py ]]; then
  echo "error: converter not found: tools/bin_to_word_hex.py" >&2
  exit 1
fi

mkdir -p "${output_dir}"

echo "[BUILD]   ${source_file}"
riscv64-unknown-elf-gcc \
  -march=rv32i \
  -mabi=ilp32 \
  -nostdlib \
  -nostartfiles \
  -Wl,--build-id=none \
  -Wl,--no-relax \
  -Wl,-T,"${linker_script}" \
  -Wl,-Map,"${map_file}" \
  -o "${elf_file}" \
  "${source_file}"

echo "[INSPECT] ${elf_file}"
riscv64-unknown-elf-objdump -d -M no-aliases "${elf_file}" > "${dump_file}"
riscv64-unknown-elf-readelf -h -S -l "${elf_file}" > "${sections_file}"
riscv64-unknown-elf-nm -n "${elf_file}" > "${symbols_file}"

echo "[EXTRACT] .text and .data"
riscv64-unknown-elf-objcopy \
  -O binary \
  --only-section=.text \
  "${elf_file}" \
  "${imem_bin}"

riscv64-unknown-elf-objcopy \
  -O binary \
  --only-section=.data \
  "${elf_file}" \
  "${dmem_bin}"

echo "[CONVERT] word-oriented little-endian HEX"
python3 tools/bin_to_word_hex.py \
  "${imem_bin}" \
  "${imem_hex}" \
  --max-words 64

python3 tools/bin_to_word_hex.py \
  "${dmem_bin}" \
  "${dmem_hex}" \
  --max-words 1024

echo "[DONE]    ${program_name}"
echo "          ELF:      ${elf_file}"
echo "          map:      ${map_file}"
echo "          dump:     ${dump_file}"
echo "          sections: ${sections_file}"
echo "          symbols:  ${symbols_file}"
echo "          IMEM HEX: ${imem_hex}"
echo "          DMEM HEX: ${dmem_hex}"
