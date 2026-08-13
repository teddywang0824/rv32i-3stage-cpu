#!/usr/bin/env python3

import csv
import sys
from pathlib import Path


EXPECTED = [
    "ADDI", "SLTI", "SLTIU", "XORI", "ORI", "ANDI", "SLLI", "SRLI",
    "SRAI", "ADD", "SUB", "SLL", "SLT", "SLTU", "XOR", "SRL", "SRA",
    "OR", "AND", "LUI", "AUIPC", "BEQ", "BNE", "BLT", "BGE", "BLTU",
    "BGEU", "JAL", "JALR", "LB", "LH", "LW", "LBU", "LHU", "SB", "SH",
    "SW", "FENCE", "ECALL", "EBREAK",
]
REQUIRED_COLUMNS = {
    "index", "mnemonic", "positive", "corner", "pipeline_or_control",
    "trap_or_illegal", "evidence",
}


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def main() -> int:
    project = Path(__file__).resolve().parent.parent
    matrix = project / "verification" / "rv32i-directed.csv"

    try:
        with matrix.open(newline="", encoding="utf-8") as stream:
            reader = csv.DictReader(stream)
            if set(reader.fieldnames or []) != REQUIRED_COLUMNS:
                return fail(f"unexpected columns in {matrix}")
            rows = list(reader)
    except OSError as error:
        return fail(f"cannot read {matrix}: {error}")

    if len(rows) != 40:
        return fail(f"expected 40 matrix rows, found {len(rows)}")

    actual = [row["mnemonic"] for row in rows]
    if actual != EXPECTED:
        return fail("mnemonic order/content does not match RV32I base 40")

    for expected_index, row in enumerate(rows, start=1):
        if row["index"] != str(expected_index):
            return fail(f"{row['mnemonic']}: expected index {expected_index}")
        for column in ("positive", "corner", "pipeline_or_control", "trap_or_illegal"):
            if not row[column].strip():
                return fail(f"{row['mnemonic']}: empty {column} coverage")

        evidence = [item.strip() for item in row["evidence"].split(";") if item.strip()]
        if not evidence:
            return fail(f"{row['mnemonic']}: no evidence")
        for relative in evidence:
            path = project / relative
            if not path.is_file():
                return fail(f"{row['mnemonic']}: missing evidence file {relative}")

    print("[PASS] RV32I directed matrix: 40/40 instructions have traceable positive, corner, pipeline/control, and trap/illegal coverage.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
