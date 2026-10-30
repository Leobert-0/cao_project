# Structural vs. Behavioral ALU & Arithmetic Architecture Suite

Project 2 from `CAO-PROJECT-2026.docx`. The original document is preserved.
Start with **docs/Project_2_Report.docx** and **docs/DEMO_GUIDE.md**.

## Run the verified portable suite

Requires Python 3 and Icarus Verilog (`iverilog` and `vvp` on PATH).

```powershell
python scripts/run_tests.py
# Faster developer check; excludes the exhaustive 8-bit run:
python scripts/run_tests.py --quick
```

On this computer the simulator is extracted under
`%LOCALAPPDATA%/cao-hdl-tools/iverilog/bin`; the runner discovers it automatically.
For another location set `$env:IVERILOG_BIN = 'C:/path/iverilog/bin'`.
Older Windows Icarus distributions require a tool installation path without spaces;
the project itself can remain in its current path.
Testbench-only `$fatal` uses Icarus `-g2012`; RTL uses Verilog-2001 syntax plus the
widely supported constant `$clog2` function. No SystemVerilog RTL constructs are used.
The runner regenerates deterministic vectors, compiles each top, records logs,
and returns a nonzero exit code on any failure. Python code uses the standard library.

## Open and run in Vivado

Use Vivado 2022.2 or later with Artix-7 device support installed. In the **Tcl Console**:

```tcl
cd {D:/Programming projects/cao project}
source scripts/create_vivado_project.tcl
launch_simulation
run all
```

The script creates `.build/vivado_gui/cao_alu_suite.xpr`. You can subsequently open
that file directly. Simulation top is `tb_top`; synthesis top is `demo_datapath`.
Click **Run Simulation > Run Behavioral Simulation**, then **Run All**.
The simulation pre-hook sets the project root as working directory so `.mem` inputs
and waveform/trace outputs resolve correctly. Do not delete `vectors/`.

To compare the **ALUs alone**, use the separate batch script from a Vivado command prompt:

```powershell
vivado -mode batch -source scripts/vivado_compare.tcl
# Optional device override:
vivado -mode batch -source scripts/vivado_compare.tcl -tclargs xc7a35tcpg236-1
```

This produces isolated out-of-context synthesis and routed reports for both ALUs,
functional/timing netlists, SDF, checkpoints, a comparison CSV, and XSim functional
netlist tests. The same 10 ns input/output maximum-delay budget and optimization
settings apply to both. Board pins are unnecessary for this software comparison.
Vivado has not been found on this computer; these scripts are provided for execution
in a Vivado installation. No Vivado measurements are claimed in the saved report.
Exported SDF is provided for optional timing simulation; the automated XSim netlist
test is **functional**, and routed static timing is the physical-delay measurement.

## Optional generic synthesis check

Install Yosys or `pip install yowasp-yosys`, then run:

```powershell
python scripts/run_synthesis.py
```

The current workspace also has a local YoWASP distribution in `.tools/yosys`.
Both designs are flattened and technology-mapped with identical `synth -noabc`
settings. This intentionally compares generic logic before ABC optimization;
results are specific to this flow, not minimum gate counts or FPGA resources.
The flow rejects inferred latches, checks the netlists, and runs 24 directed
post-synthesis vectors per implementation. No technology delay model is used.

## ALU contract

| op | Operation | Result |
|---|---|---|
| 0 | ADD | a + b, modulo 2^WIDTH |
| 1 | SUB | a - b, modulo 2^WIDTH |
| 2 | AND | a & b |
| 3 | OR | a \| b |
| 4 | XOR | a ^ b |
| 5 | SLL | logical left, truncated to WIDTH |
| 6 | SRL | logical right, zero fill |
| 7 | SLT | signed two's-complement comparison; 0 or 1 |

`C`: carry on ADD, **no borrow** on SUB. `Z`: result is zero.
`N`: result MSB. `V`: signed overflow on ADD/SUB.
Other operations clear C/V. Flag bundles and CSVs use **CZNV** ordering.
Supported WIDTH values are powers of two >=2; verified at 4, 8, 16 bits.
Shift amount is `b[$clog2(WIDTH)-1:0]` (modulo WIDTH).
There is no clock, latency register, or intrinsic cycle count in either ALU.
`alu` selects the implementation at elaboration using parameter `STRUCTURAL=1/0`.

## Demonstration datapath contract

The demonstration consumes an externally supplied 32-bit instruction and commits
one operation on each enabled rising clock edge. It has 32 eight-bit registers,
constant x0, a 256-byte memory, synchronous reset and asynchronous memory reads.
It supports ADD/SUB/AND/OR/XOR/SLL/SRL/SLT, ADDI/ANDI/ORI/XORI/SLLI/SRLI/SLTI,
LB and SB. S-type immediates and I-type immediates are sign-extended to 32 bits,
then narrowed to 8 bits. Addresses wrap modulo 256. Shift amounts are modulo 8.
LB writes the byte unchanged into an 8-bit register. This is an **educational
8-bit execution subset using RISC-V encodings**, not a complete RV32 CPU.
There is no program counter, branch unit, fetch engine, pipeline or RV32 compliance claim.
Invalid opcode/funct fields assert `invalid` and suppress all writes.
`enable=0` suppresses state changes; decoder outputs remain combinational.
Flags describe the current ALU computation, including address calculations.
Reset clears registers and memory and takes priority over enable.

## Evidence and reproducibility

- `results/verification_summary.json`: tool version, run times, source hashes, outcomes.
- `results/tb_*.log`: actual portable simulation output.
- `results/demo.vcd`, `docs/demo.gtkw`: waveform and GTKWave configuration.
- `docs/waveform_arithmetic.png`, `docs/waveform_memory.png`: annotated captures rendered from the VCD.
- `results/execution_trace.csv`: actual pre-commit datapath trace.
- `vectors/program_listing.json`: independent software-model expectations and assembly descriptions.
- `results/yosys/`: measured generic cell reports and functional netlist tests.
- `results/fault_detection.log`: expected failure from an intentionally faulty build copy;
  this confirms assertions reject a wrong result. Run `python scripts/check_failure_detection.py`
  to reproduce it; the production RTL is not modified.
- `docs/RUBRIC_CHECKLIST.md`: exact grading-category evidence and outstanding Vivado step.

To inspect the saved waveform: `gtkwave docs/demo.gtkw` from the project root.
To regenerate the Word report and technical figures, use Python with `python-docx`
and Pillow installed: `python scripts/build_report.py`. It reads current evidence;
run the full tests and optional synthesis first. Re-render and inspect the Word
report after regenerating it.
On Windows with Microsoft Word installed, `powershell -ExecutionPolicy Bypass -File
scripts/render_word.ps1` renders internal QA page images using native Word. The
delivered 11-page report was checked using this fallback because LibreOffice was
unavailable. `python scripts/package_submission.py` checks that the saved full-run
source hashes match the current HDL/testbenches and creates `Project_2_Submission.zip`.
The archive excludes installed tools, build caches, and internal report QA files.

Primary tool references: [Icarus installation documentation](https://github.com/steveicarus/iverilog/blob/master/Documentation/usage/installation.rst),
[Vivado Tcl reference](https://docs.amd.com/r/2021.1-English/ug835-vivado-tcl-commands/write_sdf),
[Vivado timing netlists](https://docs.amd.com/r/2020.2-English/ug900-vivado-logic-simulation/Generating-a-Timing-Netlist).
