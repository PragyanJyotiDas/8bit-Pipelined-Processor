# 5-Stage Pipelined RISC-V Processor (Verilog)

A classic **Fetch → Decode → Execute → Memory → Writeback** pipelined
implementation of a RISC-V RV32I subset, written in structural/behavioral
Verilog. The design follows the Harris & Harris single-cycle-to-pipeline
textbook style: each stage is its own module with its own pipeline
register, wired together in `Pipeline_Top.v`, with a dedicated
`Hazard_unit.v` handling data forwarding.

```
                 ┌────────┐   ┌────────┐   ┌─────────┐   ┌────────┐   ┌───────────┐
   PC ─────────▶ │ FETCH  │──▶│ DECODE │──▶│ EXECUTE │──▶│ MEMORY │──▶│ WRITEBACK │
                 └────────┘   └────────┘   └─────────┘   └────────┘   └───────────┘
                      ▲             ▲            │  │          │            │
                      │             │            │  │          │            │
                      └─── PCTargetE (branch) ────┘  └── forwarding (Hazard_unit) ──┘
```

## 1. Module map

| File | Role |
|---|---|
| `Pipeline_Top.v` | Top-level: instantiates the 5 stages + hazard unit and wires the pipeline registers between them |
| `Fetch_Cycle.v` | PC mux, `PC_Module`, `Instruction_Memory`, PC+4 adder, IF/ID latch |
| `Decode_Cyle.v` | `Control_Unit_Top`, `Register_File` (read), `Sign_Extend`, ID/EX latch |
| `Execute_Cycle.v` | Forwarding muxes (`Mux_3_by_1`), ALU-source mux, `ALU`, branch-target adder, EX/MEM latch |
| `Memory_Cycle.v` | `Data_Memory`, MEM/WB latch |
| `Writeback_Cycle.v` | Result mux (ALU result vs. loaded data) |
| `Hazard_unit.v` | Generates `ForwardAE`/`ForwardBE` for the Execute-stage operand muxes |
| `Control_Unit_Top.v` | Wraps `Main_Decoder` + `ALU_Decoder` |
| `Main_Decoder.v` | Opcode → `RegWrite/ImmSrc/ALUSrc/MemWrite/ResultSrc/Branch/ALUOp` |
| `ALU_Decoder.v` | `ALUOp` + `funct3`/`funct7` → 3-bit `ALUControl` |
| `ALU.v` | add/sub/and/or/slt, plus Zero/Negative/Carry/Overflow flags |
| `Register_File.v` | 32×32-bit register file, synchronous write / async read, `x0` hardwired to 0 |
| `Sign_Extend.v` | Immediate generation for I-type and S-type (see **Known Issues**) |
| `Instruction_Memory.v` | 1024-word ROM, loaded from `memfile.hex` via `$readmemh` |
| `Data_Memory.v` | 1024-word RAM, synchronous write / async read |
| `PC.v`, `PC_Adder.v`, `Mux.v` | Program counter register, generic adder, 2:1 and 3:1 muxes |
| `pipeline_tb.v` | Testbench: 100-time-unit clock, reset held low for 200 units then released, runs for 1000 units |
| `pipeline.gtkw` | Saved GTKWave signal layout (grouped by pipeline stage) for waveform inspection |

## 2. Supported instruction subset

The `Main_Decoder` only recognizes 5 opcodes, so the core supports a
minimal RV32I subset — enough for arithmetic/logic + memory + one branch:

| Opcode (bin) | Instruction type | Examples | RegWrite | ALUSrc | MemWrite | Branch |
|---|---|---|---|---|---|---|
| `0110011` | R-type | `add`, `sub`, `and`, `or`, `slt` | 1 | 0 | 0 | 0 |
| `0010011` | I-type ALU | `addi`, `andi`, `ori`, `slti` | 1 | 1 | 0 | 0 |
| `0000011` | Load | `lw` | 1 | 1 | 0 | 0 |
| `0100011` | Store | `sw` | 0 | 1 | 1 | 0 |
| `1100011` | Branch | `beq` (only equality — decided by ALU `Zero` flag) | 0 | 0 | 0 | 1 |

Not implemented: `jal`, `jalr`, `lui`, `auipc`, any branch other than
`beq` (the ALU always subtracts for `ALUOp=01`, and `PCSrcE = Zero & Branch`,
so `bne`/`blt`/etc. can't be expressed even though `funct3` is available).

**`ALUControl` encoding** (from `ALU_Decoder.v` / `ALU.v`):

| ALUControl | Operation |
|---|---|
| `000` | `A + B` (add) |
| `001` | `A - B` (subtract — also used for `beq` comparison) |
| `010` | `A & B` (and) |
| `011` | `A \| B` (or) |
| `101` | `slt` (1 if `A - B` is negative) |

## 3. Pipeline stages

1. **Fetch** — `PC_MUX` selects `PC+4` or the branch target (`PCTargetE`) based on `PCSrcE`; `Instruction_Memory` is read at the resulting PC; IF/ID registers latch instruction + PC + PC+4.
2. **Decode** — instruction fields drive `Control_Unit_Top`; `Register_File` is read for `rs1`/`rs2`; `Sign_Extend` builds the immediate; ID/EX registers latch control signals, register data, immediate, and destination/source register numbers (`RS1_E`/`RS2_E`/`RD_E`, needed by the hazard unit).
3. **Execute** — `ForwardAE`/`ForwardBE` select between the register-file value, the writeback result, or the EX/MEM ALU result for each ALU operand; `ALU` computes the result and `Zero` flag; a separate adder computes the branch target `PCTargetE`; `PCSrcE = Zero & BranchE` feeds back to Fetch.
4. **Memory** — `Data_Memory` is read/written using the ALU result as address.
5. **Writeback** — a 2:1 mux picks the ALU result (R/I-type) or loaded data (`lw`) as `ResultW`, which is written back into the register file and also fed to the Decode stage's register-file write port and to the Execute-stage forwarding muxes.

## 4. Hazard handling — how it actually works

### 4.1 Data hazards (RAW) — handled via forwarding

`Hazard_unit.v` compares the **Execute stage's source registers**
(`Rs1_E`, `Rs2_E`, latched in Decode) against the destination registers
sitting in the **Memory** (`RD_M`) and **Writeback** (`RD_W`) pipeline
stages:

```verilog
ForwardAE = (RegWriteM & (RD_M != 0) & (RD_M == Rs1_E)) ? 2'b10 :  // forward from EX/MEM
            (RegWriteW & (RD_W != 0) & (RD_W == Rs1_E)) ? 2'b01 :  // forward from MEM/WB
                                                            2'b00;  // no hazard, use RF value
```
(same logic for `ForwardBE` against `Rs2_E`)

These 2-bit codes drive the `Mux_3_by_1` instances in `Execute_Cycle.v`
(`srca_mux`, `srcb_mux`):
- `00` → register-file value read in Decode (`RD1_E`/`RD2_E`)
- `01` → the Writeback-stage result (`ResultW`) — MEM/WB forward
- `10` → the Memory-stage ALU result (`ALU_ResultM`) — EX/MEM forward

The priority is correct (EX/MEM is checked first, since it's the more
recent value), and `x0` is excluded from triggering a forward. This
resolves the classic **ALU-to-ALU** RAW hazard (e.g. `add x1,...` followed
immediately by an instruction reading `x1`) without stalling.

### 4.2 Data hazards — what is *not* handled

**Load-use hazard.** There is no hazard-detection/stall logic anywhere in
the design (no `StallF`/`StallD`/`FlushE` signals, no bubble injection).
A `lw` immediately followed by an instruction that consumes the loaded
register cannot be resolved by forwarding alone — the loaded value isn't
available until the end of the Memory stage, one cycle *after* the
dependent instruction has already used the (still-in-flight) EX/MEM
value. As written, `ForwardAE`/`ForwardBE` would forward `ALU_ResultM`
(the load's *address*, not its data) to the dependent instruction one
cycle too early, producing an incorrect result. A textbook fix is a
`StallD`/`StallF`/`FlushE` signal generated from
`(ResultSrcE == 1) & ((RD_E == Rs1_D) | (RD_E == Rs2_D))` that stalls the
Decode/Fetch stages and inserts one bubble into Execute — that logic is
absent here.

### 4.3 Control hazards (branches)

`beq` is resolved in the **Execute** stage: `PCSrcE = Zero & BranchE`
redirects Fetch to `PCTargetE` the cycle after the branch reaches
Execute. However, there is **no flush of the two instructions that were
already fetched/decoded speculatively** (no `FlushD`/`FlushE` clearing
the IF/ID or ID/EX registers on a taken branch). On a taken branch, the
instruction currently in Decode and the one currently in Fetch will
continue down the pipeline and (if they have side effects such as
`RegWrite`/`MemWrite`) incorrectly execute. In effect, this core assumes
"predict not-taken" but never squashes the wrong-path instructions, so
taken branches are not architecturally correct yet — this is the main
piece needed to complete the control-hazard story.

### 4.4 Structural note: register file same-cycle write/read

`Register_File.v` writes on `posedge clk` and reads combinationally, and
`Writeback_Cycle`'s `ResultW` is also fed straight into `Decode_Cyle`'s
register-file write port. If the instruction currently in Writeback and
the instruction currently in Decode share a register, correctness
depends on simulator/synthesis write-before-read ordering rather than an
explicit forwarding path — worth being aware of if results look off by
one cycle for back-to-back dependent instructions spaced exactly 3 apart.

## 5. Known issues found while reviewing the RTL

- **`Fetch_Cycle.v`: the IF/ID output assignments are commented out.**
  `InstrD`, `PCD`, and `PCPlus4D` are declared as outputs but never
  driven (the `assign` block right below the register logic is commented
  out) — as it stands these three wires float. Uncomment/restore:
  ```verilog
  assign InstrD   = (rst == 1'b0) ? 32'h0 : InstrF_reg;
  assign PCD      = (rst == 1'b0) ? 32'h0 : PCF_reg;
  assign PCPlus4D = (rst == 1'b0) ? 32'h0 : PCPlus4F_reg;
  ```
- **`Sign_Extend.v` doesn't generate the branch immediate.** `ImmSrc == 2'b10`
  (set by `Main_Decoder` for opcode `1100011`, branches) isn't handled —
  it falls into the default case and returns `32'h0`. This means `beq`'s
  branch offset is always 0, so `PCTargetE` always equals `PCE`. Needs a
  B-type (SB) immediate case, e.g.:
  ```verilog
  (ImmSrc == 2'b10) ? {{20{In[31]}}, In[7], In[30:25], In[11:8], 1'b0} :
  ```
- **No load-use stall / no branch flush** — see §4.2 and §4.3 above.
- **`Data_Memory.v` indexes `mem[A]` with the raw byte address** (the full
  ALU result), unlike `Instruction_Memory.v` which shifts by 2
  (`mem[A[31:2]]`). Loads/stores to the same address still round-trip
  correctly since both read and write use the same indexing, but it
  wastes array capacity (only byte-addresses 0–1023 are reachable, i.e.
  effectively 256 usable word slots on 4-byte-aligned accesses) and isn't
  representative of real byte-addressable memory.
- **No `jal`/`jalr`/`lui`/`auipc`, and only `beq`** — see §2. If you need
  loops/function calls or other branch conditions, `Main_Decoder`,
  `ALU_Decoder`, `Sign_Extend`, and the Writeback mux (to add a
  PC+4-as-result path for `jal`) all need extending.

## 6. Determining which program is running

`Instruction_Memory.v` loads its contents at elaboration time via
`$readmemh("memfile.hex", mem)` — **`memfile.hex` was not included in
this upload**, so the actual program executed by the testbench isn't
determinable from the files here alone. To find out what's running:
- Look for `memfile.hex` alongside these sources (same directory the
  simulator is run from) and decode it directly, or
- Run the simulation and inspect `InstrD`/`InstrF` in the waveform
  (`pipeline.gtkw` already groups `tb.dut.InstrD[31:0]` under
  "Fetch_Cycle"), or
- Regenerate `memfile.hex` yourself with a RISC-V assembler targeting the
  subset in §2.

For reference, `Instruction_Memory.v` also keeps a commented-out example
program that shows the expected instruction encodings, e.g.
`32'h0062E233` decodes to `or x4, x5, x6` (opcode `0110011`, `funct3=110`,
`funct7=0000000`), and `32'hFFC4A303` decodes to `lw x6, -4(x9)`.

## 7. Simulating

```bash
iverilog -o pipeline_sim pipeline_tb.v Pipeline_Top.v
vvp pipeline_sim
gtkwave dump.vcd pipeline.gtkw
```

Reset (`rst`) is held low for 200 time units (all pipeline registers and
the PC clear to 0), then released; the testbench runs for 1000 further
units before `$finish`. `Pipeline_Top.v` `` `include``s every submodule,
so a single top-level + testbench compile is enough — no separate file
list needed.
