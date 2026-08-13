#!/usr/bin/env python3

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path


CONVERTER = Path(__file__).with_name("bin_to_word_hex.py")


class BinToWordHexTests(unittest.TestCase):
    def run_converter(
        self,
        input_path: Path,
        output_path: Path,
        max_words: int,
    ) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [
                sys.executable,
                str(CONVERTER),
                str(input_path),
                str(output_path),
                "--max-words",
                str(max_words),
            ],
            text=True,
            capture_output=True,
            check=False,
        )

    def test_little_endian_words(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "input.bin"
            output_path = root / "output.hex"
            input_path.write_bytes(
                bytes.fromhex("83 20 00 00 03 21 40 00")
            )

            result = self.run_converter(input_path, output_path, 2)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                output_path.read_text(encoding="ascii"),
                "00002083\n00402103\n",
            )
            self.assertIn("converted 8 bytes into 2 words", result.stdout)

    def test_partial_word_is_zero_padded(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "padding.bin"
            output_path = root / "padding.hex"
            input_path.write_bytes(bytes.fromhex("83 20 00"))

            result = self.run_converter(input_path, output_path, 1)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(
                output_path.read_text(encoding="ascii"), "00002083\n"
            )
            self.assertIn("converted 3 bytes into 1 words", result.stdout)

    def test_empty_binary_produces_empty_hex(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "empty.bin"
            output_path = root / "empty.hex"
            input_path.write_bytes(b"")

            result = self.run_converter(input_path, output_path, 64)

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(output_path.is_file())
            self.assertEqual(output_path.read_bytes(), b"")
            self.assertIn("converted 0 bytes into 0 words", result.stdout)

    def test_imem_oversize_is_rejected_without_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "oversize_imem.bin"
            output_path = root / "oversize_imem.hex"
            input_path.write_bytes(bytes(257))

            result = self.run_converter(input_path, output_path, 64)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("requires 65 words", result.stderr)
            self.assertIn("limit is 64 words", result.stderr)
            self.assertFalse(output_path.exists())

    def test_dmem_oversize_is_rejected_without_output(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "oversize_dmem.bin"
            output_path = root / "oversize_dmem.hex"
            input_path.write_bytes(bytes(4097))

            result = self.run_converter(input_path, output_path, 1024)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("requires 1025 words", result.stderr)
            self.assertIn("limit is 1024 words", result.stderr)
            self.assertFalse(output_path.exists())

    def test_missing_input_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "not_found.bin"
            output_path = root / "not_found.hex"

            result = self.run_converter(input_path, output_path, 64)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn("input file does not exist", result.stderr)
            self.assertFalse(output_path.exists())

    def test_non_positive_word_limit_is_rejected(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            input_path = root / "input.bin"
            output_path = root / "output.hex"
            input_path.write_bytes(bytes(4))

            result = self.run_converter(input_path, output_path, 0)

            self.assertNotEqual(result.returncode, 0)
            self.assertIn(
                "--max-words must be greater than zero", result.stderr
            )
            self.assertFalse(output_path.exists())


if __name__ == "__main__":
    unittest.main(verbosity=2)
