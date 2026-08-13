#!/usr/bin/env python3

import argparse
import sys
from pathlib import Path


def parse_args():
    parser = argparse.ArgumentParser(
        description=(
            "Convert a little-endian raw binary into "
            "$readmemh-compatible 32-bit word HEX."
        )
    )

    parser.add_argument(
        "input",
        type=Path,
        help="Input raw binary file",
    )
    parser.add_argument(
        "output",
        type=Path,
        help="Output word-oriented HEX file",
    )
    parser.add_argument(
        "--max-words",
        type=int,
        required=True,
        help="Maximum number of 32-bit words",
    )

    return parser.parse_args()


def fail(message):
    print(f"error: {message}", file=sys.stderr)
    return 1


def main():
    args = parse_args()

    if args.max_words <= 0:
        return fail("--max-words must be greater than zero")

    if not args.input.is_file():
        return fail(f"input file does not exist: {args.input}")

    try:
        binary = args.input.read_bytes()
    except OSError as error:
        return fail(f"cannot read {args.input}: {error}")

    required_words = (len(binary) + 3) // 4

    if required_words > args.max_words:
        return fail(
            f"{args.input} requires {required_words} words, "
            f"but the limit is {args.max_words} words"
        )

    # Pad the final partial word with zero bytes.
    padding = (-len(binary)) % 4
    binary += bytes(padding)

    words = []

    for offset in range(0, len(binary), 4):
        chunk = binary[offset:offset + 4]
        word = int.from_bytes(chunk, byteorder="little")
        words.append(f"{word:08x}")

    try:
        args.output.parent.mkdir(parents=True, exist_ok=True)

        content = "\n".join(words)
        if words:
            content += "\n"

        args.output.write_text(content, encoding="ascii")
    except OSError as error:
        return fail(f"cannot write {args.output}: {error}")

    print(
        f"converted {len(binary) - padding} bytes "
        f"into {required_words} words: {args.output}"
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())