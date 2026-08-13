# RV32I Core v1.0 RTL quality audit

Date: 2026-08-13

| Audit item | Result | Evidence |
| --- | --- | --- |
| Reset clears architectural/pipeline/trap state | PASS | `PC`, `IDEX`, `EXWB`, `Reg_File`, `Trap_Unit` reset branches；unit regression |
| Reset suppresses external request and retire side effects | PASS | `CPU_Core` gates IMEM/DMEM request and retire-valid/write flags with `!rst` |
| Invalid/illegal instruction has no side effect | PASS | safe decode defaults；`tb_Control_Unit`, `tb_CPU_Illegal` |
| x0 remains zero | PASS | write suppression/read mux；`tb_Reg_File`, load-to-x0 hazard case |
| Load-use stall holds PC/response and inserts one bubble | PASS | `Hazard_Unit` + `bubble_IDEX`；`tb_CPU_Load_Hazard` |
| Redirect kills wrong path | PASS | redirect/kill/bubble arbitration；Branch/JAL/JALR/Store integration tests |
| Trap suppresses faulting and younger side effects | PASS | `effective_ex_*` gating；`tb_CPU_Trap`, `tb_CPU_Alignment` |
| Trap metadata stable until ack and redirect resumes | PASS | `Trap_Unit` pending register；`tb_Trap_Unit`, CPU trap integration |
| Store commits and retires once in fixed-latency contract | PASS | EX/WB store commit payload；retire/directed ordered traces |
| Load response reaches corresponding instruction | PASS | single outstanding, fixed next-cycle response；load/load-hazard tests |
| FENCE has no state side effect and retires | PASS | FENCE unit/integration/directed tests |
| Synthesizable hierarchy lint | PASS | Verilator 4.038, `bash tools/run_rtl_lint.sh`, zero diagnostics |

## Frozen limitations

- Reset is synchronous and active-high. Outputs are explicitly suppressed while `rst=1`; state changes occur on the rising edge.
- IMEM and DMEM have no ready/backpressure or transaction ID. v1.0 supports one in-order request with a fixed next-cycle response only.
- Simulation memories do not produce access-fault traps for out-of-range addresses; test images must fit the configured capacity.
- No CSR, privileged mode, interrupt, RV32M, RVC, cache, MMU, PMP, variable-latency memory or physical SRAM macro.

These limitations are release contracts, not untracked lint waivers.
