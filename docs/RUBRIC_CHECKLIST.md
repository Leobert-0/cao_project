# Grading rubric evidence

This maps the shared rubric to Project 2. It is evidence of coverage, not a guarantee of marks.

| Category | Weight | Implemented evidence |
|---|---:|---|
| Functional correctness and logic | 40 | Exhaustive 8-bit ALU and add/sub checks; CZNV checks; decoder R/I/S vectors; MUX/register/memory demo |
| Automated testbench and verification | 20 | `tb_top.v`, independent golden models, `$readmemh`, structured loops, `$display`/`$error`/`$fatal`, process failure codes |
| Coding quality and synthesizability | 20 | Modular gate hierarchy, parameterized widths, complete combinational blocks, sequential nonblocking assignments; Yosys latch rejection and netlist checks |
| Simulation deliverables and waveforms | 10 | Saved VCD, GTKWave signal configuration, two annotated captures from actual VCD data, instruction trace |
| Documentation and block diagram | 10 | Word report, full signal diagram, operation/flag contract, execution trace, demonstration guide |

## Project 2 comparison requirements

- Structural and behavioral ALUs share the same operations and flag contract.
- Generic synthesis cell counts are measured in `results/yosys/`; both functional netlists pass directed tests.
- Simulation vector counts, simulated duration, and wall runtime are identified separately.
- **Pending:** Vivado device resource reports and constrained propagation-delay comparison.
  Scripts are included, but Vivado was not available for execution here.
- **Not claimed:** board validation, full RV32 execution, measured physical propagation
  from zero-delay RTL, or SDF timing-simulation validation.

Before course submission: fill in name/ID/course details in the Word report; run
the supplied Vivado flow on the course machine and attach its real reports if required.
