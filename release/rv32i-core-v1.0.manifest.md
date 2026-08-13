# RV32I Core v1.0 release manifest

Release date: 2026-08-13

Release identity: annotated Git tag `rv32i-core-v1.0`

Release commit lookup: `git rev-parse rv32i-core-v1.0^{commit}`

Pre-release baseline: `8e0e6e3cd7af399566159b3c5e613652eea643f4`

## Scope

- Four-stage, single-issue, in-order RV32I core.
- 40 RV32I base instructions including FENCE, ECALL and EBREAK.
- Precise synchronous trap handshake and in-order retire trace.
- Synthesis top: `CPU_Core`.
- Architectural contract: `docs/rv32i-core-spec.md`.

## Frozen synthesis source list

```text
rtl/CPU_Core.sv
rtl/Controller.sv
rtl/PC.sv
rtl/Inst_Decoder.sv
rtl/Reg_File.sv
rtl/Control_Unit.sv
rtl/IDEX.sv
rtl/EXWB.sv
rtl/ALU.sv
rtl/Forwarding_Unit.sv
rtl/Hazard_Unit.sv
rtl/Branch_Unit.sv
rtl/Store_Unit.sv
rtl/Load_Unit.sv
rtl/Trap_Detect.sv
rtl/Trap_Unit.sv
```

`rtl/defines.sv` is included by source files and is part of the release inputs. SHA-256 values for the hierarchy are recorded in `release/rv32i-core-v1.0.rtl.sha256`.

Excluded from synthesis hierarchy:

- `CPU_Sim_Top`, `CPU_Top`, `Program_ROM`, `Data_Memory`, `Arch_Test_Memory`: simulation/compatibility wrappers.
- `IFID.sv`: synthesizable teaching/alternative module, not instantiated by v1.0 `CPU_Core`.

## Frozen interface contracts

- `rst`: synchronous active-high; request and retire side effects are suppressed while asserted.
- IMEM: request/address, fixed next-cycle valid/PC/instruction response, no ready or backpressure.
- DMEM: request/write/byte-enable/address/data, fixed next-cycle Load response; Store commits on request edge.
- At most one in-order memory transaction is supported; no transaction ID or variable latency.
- Trap: metadata remains stable while `trap_valid`; `trap_ack` accepts it and samples `trap_redirect_pc` on the rising edge.
- Retire: one in-order observation for each legal non-faulting instruction, including committed rd/store payload.

## Quality and regression evidence

| Check | Tool/command | Result |
| --- | --- | --- |
| Synthesizable hierarchy lint | Verilator 4.038, `bash tools/run_rtl_lint.sh` | zero diagnostics |
| Complete regression | `bash run_tests.sh all` | PASS |
| Directed ISA matrix | `bash run_tests.sh directed` | 40/40 instructions |
| ACT4 architectural tests | `bash run_tests.sh arch` | 39 passed, 0 failed |
| Freestanding C workload | `bash run_tests.sh compiled` | two identical runs, 1304 cycles / 902 retired |

Final regression log: `build/rv32i-v1.0-regression.log`

Final regression log SHA-256: `00d1a109c8db50425aa91ad907705003d8c10929bca2b84e2ef33054568b1d68`

The build directory is intentionally not versioned. Reproduce the log using the README instructions and compare the hash only when using the locked tool versions.

## Validated tool versions

- Icarus Verilog 11.0
- Verilator 4.038
- Python 3.10.12
- ACT4/riscv-arch-test commit `b664a56b7b24a0ba7512f8df064f9e799e33c892`
- ACT4 compiler GCC 15.2.0 / Binutils 2.45
- Sail RISC-V 0.13.1
- mise 2026.8.5

## Known limitations

- No CSR, privileged mode, interrupt, RV32M, RVC, atomic or floating-point extension.
- No cache, MMU, PMP, bus protocol, wait-state/backpressure or multiple outstanding transactions.
- No physical SRAM macro; provided memory implementations are simulation models.
- Misaligned instruction/Load/Store accesses trap; hardware does not split cross-word data accesses.
- No access-fault exception for a simulation image exceeding configured memory capacity.

Detailed reset/valid/side-effect evidence is recorded in `verification/rtl-quality-audit.md`.
