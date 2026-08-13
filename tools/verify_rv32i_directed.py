#!/usr/bin/env python3

import re
import sys
from pathlib import Path


EXPECTED_MNEMONICS = {
    "addi", "slti", "sltiu", "xori", "ori", "andi", "slli", "srli",
    "srai", "add", "sub", "sll", "slt", "sltu", "xor", "srl", "sra",
    "or", "and", "lui", "auipc", "beq", "bne", "blt", "bge", "bltu",
    "bgeu", "jal", "jalr", "lb", "lh", "lw", "lbu", "lhu", "sb", "sh",
    "sw", "fence", "ebreak",
}


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def main() -> int:
    root = Path("build/programs/rv32i_directed")
    dump_path = root / "rv32i_directed.dump"
    hex_path = root / "rv32i_directed_imem.hex"

    try:
        dump = dump_path.read_text(encoding="ascii")
        words = [line.strip() for line in hex_path.read_text(encoding="ascii").splitlines() if line.strip()]
    except OSError as error:
        return fail(str(error))

    pattern = re.compile(
        r"^\s*([0-9a-f]+):\s+([0-9a-f]{8})\s+([a-z0-9.]+)\b",
        re.MULTILINE,
    )
    instructions = [(int(a, 16), word, mnemonic) for a, word, mnemonic in pattern.findall(dump)]
    mnemonics = {mnemonic for _, _, mnemonic in instructions}

    missing = sorted(EXPECTED_MNEMONICS - mnemonics)
    if missing:
        return fail("directed ELF is missing instruction(s): " + ", ".join(missing))
    if len(words) != 43 or len(instructions) != 43:
        return fail(f"expected 43 instructions/HEX words, got dump={len(instructions)} hex={len(words)}")

    for index, (address, word, _) in enumerate(instructions):
        if address != index * 4 or word.lower() != words[index].lower():
            return fail(f"objdump/HEX mismatch at instruction {index}")
    if instructions[-1] != (0xA8, "00100073", "ebreak"):
        return fail("directed program must terminate with EBREAK at 0x000000a8")

    print("[PASS] rv32i_directed ELF/HEX contains all 38 normally retiring RV32I instructions plus EBREAK in 43 ordered words.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
