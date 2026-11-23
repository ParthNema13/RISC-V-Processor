# 32-bit Single-Cycle RISC-V Processor

A small 32-bit CPU written in Verilog HDL. It follows the RISC-V RV32I instruction set and runs one instruction per clock cycle. The project includes a self-checking testbench that runs a test program and verifies the results.

## Supported Instructions

| Type | Instructions | Purpose |
|---|---|---|
| R-type | `ADD`, `SUB`, `AND`, `OR` | Arithmetic and logic between two registers |
| I-type | `ADDI` | Add a constant to a register |
| I-type | `LW` | Load a 32-bit word from data memory |
| S-type | `SW` | Store a 32-bit word to data memory |
| B-type | `BEQ` | Branch if two registers are equal |

## Architecture

The processor is a single-cycle datapath. Each clock cycle it performs fetch, decode, execute, memory access, and write-back.

| Module | Role |
|---|---|
| `riscv_single_cycle` | Top level. Holds the program counter (PC), computes PC+4 and branch targets, and connects all units. |
| `imem` | Instruction memory (256 words). Preloaded with the test program. |
| `regfile` | 32 general-purpose registers (x0 to x31). x0 is hardwired to zero. |
| `control_unit` | Decodes the opcode and generates control signals. |
| `imm_gen` | Builds and sign-extends the immediate value for each instruction type. |
| `alu_control` | Chooses the exact ALU operation from `alu_op`, `funct3`, and `funct7`. |
| `alu` | Performs AND, OR, ADD, SUB and outputs a `zero` flag. |
| `dmem` | Data memory (256 words). Read by `LW`, written by `SW`. |

## Project Structure

```
riscv_single_cycle/
├── riscv_single_cycle.v      # Processor design (all modules)
├── tb_riscv_single_cycle.v   # Testbench
├── RISC-V_Processor_Project_Report.md  # Detailed report and interview prep
└── README.md
```

## Test Program

The instruction memory holds this program:

```
addi x1, x0, 5        # x1 = 5
addi x2, x0, 10       # x2 = 10
add  x3, x1, x2       # x3 = 15
sub  x4, x2, x1       # x4 = 5
and  x8, x1, x2       # x8 = 0
or   x9, x1, x2       # x9 = 15
sw   x3, 0(x0)        # mem[0] = 15
lw   x5, 0(x0)        # x5 = 15
beq  x3, x5, +8       # equal, so skip the next instruction
addi x6, x0, 1        # skipped, x6 stays 0
addi x7, x0, 99       # x7 = 99
beq  x0, x0, 0        # halt (infinite loop)
```

## Running the Simulation

### Option 1: Icarus Verilog (command line)

Install Icarus Verilog, then run:

```bash
iverilog -g2005 -o sim.out riscv_single_cycle.v tb_riscv_single_cycle.v
vvp sim.out
```

Expected output:

```
---- Register checks ----
PASS: x1 = 5
PASS: x2 = 10
PASS: x3 = 15
PASS: x4 = 5
PASS: x5 = 15
PASS: x6 = 0
PASS: x7 = 99
PASS: x8 = 0
PASS: x9 = 15
---- Memory checks ----
PASS: mem[0] = 15
==> ALL TESTS PASSED
```

The run also creates `riscv_single_cycle.vcd`, a waveform file. Open it in GTKWave to see signals over time.

### Option 2: Xilinx Vivado

1. Create a new RTL project.
2. Add `riscv_single_cycle.v` as a **design source**.
3. Add `tb_riscv_single_cycle.v` as a **simulation source**.
4. Right-click `tb_riscv_single_cycle` under Simulation Sources and choose **Set as Top**.
5. In the Flow Navigator, click **Run Simulation → Run Behavioral Simulation**.
6. Check the Tcl console for PASS/FAIL messages and use the waveform window to inspect signals.

To synthesize, set `riscv_single_cycle` as the top design module and run **Run Synthesis**.

## Adding a New Test Program

Edit the `mem[...]` assignments inside the `initial` block in `imem`. Each entry is a 32-bit machine-code word. Update the expected values in `tb_riscv_single_cycle.v` to match.

## Limitations

- Single-cycle design, so the clock period must cover the slowest instruction.
- Only 8 instructions are implemented.
- No pipelining and no hazard handling.
- Memory accesses are word-only (no LB, SH, etc.).
- The program is fixed in the source code and is not loaded from a file.

## Possible Extensions

- Add more instructions (LUI, AUIPC, JAL, JALR, BNE, BLT).
- Load programs from a hex file using `$readmemh`.
- Convert the design into a 5-stage pipeline.
