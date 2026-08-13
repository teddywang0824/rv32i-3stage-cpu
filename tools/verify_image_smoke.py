#!/usr/bin/env python3

import argparse
import re
import sys
from pathlib import Path


EXPECTED_IMEM = [
    0x00002083,  # lw x1, 0(x0)
    0x00402103,  # lw x2, 4(x0)
    0x002081B3,  # add x3, x1, x2
    0x00302423,  # sw x3, 8(x0)
    0x00100073,  # ebreak
]

EXPECTED_DMEM = [5, 7, 0]


def fail(message: str) -> int:
    print(f"error: {message}", file=sys.stderr)
    return 1


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="ascii")
    except OSError as error:
        raise RuntimeError(f"cannot read {path}: {error}") from error


def read_hex_words(path: Path) -> list[int]:
    words = []
    for line_number, line in enumerate(read_text(path).splitlines(), start=1):
        value = line.strip()
        if not value:
            continue
        if not re.fullmatch(r"[0-9a-fA-F]{8}", value):
            raise RuntimeError(
                f"{path}:{line_number}: expected one 8-digit hexadecimal word"
            )
        words.append(int(value, 16))
    return words


def parse_dump_words(dump: str) -> dict[int, int]:
    words = {}
    pattern = re.compile(r"^\s*([0-9a-fA-F]+):\s+([0-9a-fA-F]{8})\b", re.MULTILINE)
    for match in pattern.finditer(dump):
        address = int(match.group(1), 16)
        words[address] = int(match.group(2), 16)
    return words


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Verify image_smoke ELF reports, HEX images, and golden payload."
    )
    parser.add_argument(
        "output_dir",
        type=Path,
        nargs="?",
        default=Path("build/programs/image_smoke"),
    )
    args = parser.parse_args()

    base = args.output_dir
    paths = {
        "dump": base / "image_smoke.dump",
        "sections": base / "image_smoke.sections.txt",
        "symbols": base / "image_smoke.symbols.txt",
        "imem": base / "image_smoke_imem.hex",
        "dmem": base / "image_smoke_dmem.hex",
    }

    missing = [str(path) for path in paths.values() if not path.is_file()]
    if missing:
        return fail("missing generated artifact(s): " + ", ".join(missing))

    try:
        dump = read_text(paths["dump"])
        sections = read_text(paths["sections"])
        symbols = read_text(paths["symbols"])
        imem_words = read_hex_words(paths["imem"])
        dmem_words = read_hex_words(paths["dmem"])
    except RuntimeError as error:
        return fail(str(error))

    if not re.search(r"Entry point address:\s+0x0\b", sections):
        return fail("ELF entry point is not 0x00000000")
    if not re.search(r"\] \.text\s+PROGBITS\s+00000000\b", sections):
        return fail(".text is not linked at 0x00000000")
    if not re.search(r"\] \.data\s+PROGBITS\s+10000000\b", sections):
        return fail(".data is not linked at 0x10000000")
    if not re.search(r"^00000000\s+\S\s+_start$", symbols, re.MULTILINE):
        return fail("_start symbol is not 0x00000000")

    if imem_words != EXPECTED_IMEM:
        return fail(
            "IMEM HEX differs from image_smoke golden words: "
            + " ".join(f"{word:08x}" for word in imem_words)
        )
    if dmem_words != EXPECTED_DMEM:
        return fail(
            "DMEM HEX differs from image_smoke golden words: "
            + " ".join(f"{word:08x}" for word in dmem_words)
        )

    dump_words = parse_dump_words(dump)
    for word_index, expected_word in enumerate(imem_words):
        address = word_index * 4
        actual_word = dump_words.get(address)
        if actual_word != expected_word:
            return fail(
                f"objdump/IMEM mismatch at 0x{address:08x}: "
                f"dump={actual_word!s} hex=0x{expected_word:08x}"
            )

    if not re.search(r"^\s*c:\s+00302423\s+.*\bsw\b", dump, re.MULTILINE):
        return fail("Store instruction is missing at 0x0000000c")
    if not re.search(r"^\s*10:\s+00100073\s+.*\bebreak\b", dump, re.MULTILINE):
        return fail("EBREAK instruction is missing at 0x00000010")

    print(
        "[PASS] image_smoke artifacts agree: entry/_start, sections, "
        "objdump, IMEM HEX, and DMEM golden data."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
