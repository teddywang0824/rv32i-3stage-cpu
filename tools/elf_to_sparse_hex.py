#!/usr/bin/env python3
"""Convert a little-endian ELF32 image into sparse word-oriented readmemh."""

from __future__ import annotations

import argparse
import struct
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIIIIIHHHHHH")
PROGRAM_HEADER = struct.Struct("<IIIIIIII")
PT_LOAD = 1
EM_RISCV = 243


def load_elf(path: Path, memory_bytes: int) -> dict[int, int]:
    image = path.read_bytes()
    if len(image) < ELF_HEADER.size:
        raise ValueError("file is too small to be an ELF32 image")

    header = ELF_HEADER.unpack_from(image)
    ident = header[0]
    if ident[:4] != b"\x7fELF" or ident[4] != 1 or ident[5] != 1:
        raise ValueError("only little-endian ELF32 images are supported")
    if header[2] != EM_RISCV:
        raise ValueError(f"expected RISC-V e_machine={EM_RISCV}, got {header[2]}")

    phoff, phentsize, phnum = header[5], header[9], header[10]
    if phentsize < PROGRAM_HEADER.size:
        raise ValueError("ELF program header is smaller than ELF32_Phdr")

    memory: dict[int, int] = {}
    for index in range(phnum):
        offset = phoff + index * phentsize
        if offset + PROGRAM_HEADER.size > len(image):
            raise ValueError("truncated ELF program-header table")
        p_type, p_offset, p_vaddr, p_paddr, p_filesz, p_memsz, _, _ = PROGRAM_HEADER.unpack_from(image, offset)
        if p_type != PT_LOAD or p_memsz == 0:
            continue
        address = p_paddr if p_paddr else p_vaddr
        end = address + p_memsz
        if end > memory_bytes:
            raise ValueError(
                f"PT_LOAD 0x{address:08x}..0x{end - 1:08x} exceeds "
                f"configured memory size 0x{memory_bytes:x}"
            )
        if p_filesz > p_memsz or p_offset + p_filesz > len(image):
            raise ValueError("invalid or truncated PT_LOAD segment")

        segment = image[p_offset : p_offset + p_filesz] + bytes(p_memsz - p_filesz)
        for byte_offset, value in enumerate(segment):
            byte_address = address + byte_offset
            previous = memory.get(byte_address)
            if previous is not None and previous != value:
                raise ValueError(f"conflicting PT_LOAD data at 0x{byte_address:08x}")
            memory[byte_address] = value

    if not memory:
        raise ValueError("ELF contains no loadable bytes")
    return memory


def write_sparse_words(memory: dict[int, int], output: Path) -> int:
    words: dict[int, int] = {}
    for address, value in memory.items():
        word_address = address >> 2
        shift = (address & 3) * 8
        words[word_address] = (words.get(word_address, 0) & ~(0xFF << shift)) | (value << shift)

    output.parent.mkdir(parents=True, exist_ok=True)
    previous = -2
    with output.open("w", encoding="ascii", newline="\n") as stream:
        for address in sorted(words):
            if address != previous + 1:
                stream.write(f"@{address:08x}\n")
            stream.write(f"{words[address]:08x}\n")
            previous = address
    return len(words)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("elf", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--memory-bytes", type=lambda value: int(value, 0), default=0x02000000)
    args = parser.parse_args()

    memory = load_elf(args.elf, args.memory_bytes)
    word_count = write_sparse_words(memory, args.output)
    print(f"converted {args.elf.name}: {word_count} initialized words -> {args.output}")


if __name__ == "__main__":
    main()
