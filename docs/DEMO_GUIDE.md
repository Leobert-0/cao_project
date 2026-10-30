# Project 2 demonstration guide (about 6 minutes)

1. **Objective (30 seconds).** Open the architecture diagram. Explain that identical
   ALU behavior is expressed with two HDL styles. Structural hierarchy is half adder
   -> full adder -> ripple carry -> adder/subtractor -> ALU. Behavioral RTL uses
   arithmetic operators, a case statement, and signed comparison.
2. **Source walkthrough (1 minute).** Show `rtl/structural.v` and `rtl/behavioral.v`.
   Point out the structural barrel shifter and MUX tree. Show the interface and
   explain C on subtraction means no borrow. Both are combinational circuits.
3. **Automatic verification (1 minute).** Run `python scripts/run_tests.py` or show
   the saved logs if time is limited. The 8-bit run takes roughly a minute on this
   computer. Explain the integer-range golden model and why comparing the two
   implementations without a third reference would be insufficient.
4. **Waveform (1 minute).** In GTKWave open `docs/demo.gtkw`, or show the PNG captures.
   At step 2, FF+01 produces 00 with CZNV=1100. At step 4, 7F+01 produces 80 with
   CZNV=0011. At step 7, 05-0A produces FB with CZNV=0010. In the memory capture,
   show SB writing FB at address 03, LB reading it, and the disabled store preserving it.
5. **Comparison (1 minute).** Open `results/yosys/comparison.csv`: structural 352
   generic cells versus behavioral 309 for the saved no-ABC flow. These counts
   depend on synthesis settings. Do not claim FPGA LUT counts, physical delay, or
   universal superiority from them. In a Vivado installation run
   `vivado -mode batch -source scripts/vivado_compare.tcl` for target-specific reports.
6. **Rubric close (30 seconds).** Show the Word report and checklist. Explain the
   small decoder/MUX demonstration covers the shared rubric without changing the
   isolated ALU benchmark. Identify Vivado measurements as pending until executed.

## Likely questions

**Why can behavioral RTL use fewer cells?** The tool recognizes arithmetic and
comparison operators and optimizes them. Structural intent can be optimized too;
the final mapping is determined by the synthesis tool, target and settings.

**Are #1 or #20 delays hardware delays?** No. Testbench delays provide settling
intervals for a zero-delay RTL or functional netlist simulation. Physical delay
comes from constrained synthesis/implementation timing or an annotated timing simulation.

**What does V mean versus C?** V indicates signed range overflow; C describes
unsigned carry/no-borrow. FF+01 has C=1,V=0. 7F+01 has C=0,V=1.

**Why is this not RV32?** Only instruction encodings and a small decoding subset
are reused. Data/registers and addresses are eight bits; shifts use three low bits.

**Why no execution-cycle speedup?** Both ALUs are combinational. The demo uses one
enabled edge per instruction for visibility. Simulator runtime measures software
workload rather than the hardware clock frequency.
