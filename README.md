# RISC-V VAES Coprocessor

This package implements a 5-stage AES-oriented vector coprocessor with AXI4-Stream ingress/egress, a 32 x 128-bit vector register file, a self-checking Verilator testbench, and the required design collateral.

## Pipeline

The coprocessor uses a normal 5-stage pipeline:

1. IF - instruction capture from the AXI4-Stream ingress packet
2. ID - decode and register read
3. EX - execute; `vaes.sbox.v` and `vaes.mcol.v` are modeled as multi-cycle operations with dedicated parallel units
4. MEM - result alignment / pipeline buffering
5. WB - vector register file write-back

## Directory layout

- `rtl/` - synthesizable SystemVerilog RTL
- `tb/` - self-checking SystemVerilog testbench, reference model class, and example sequence files
- `docs/` - ISA definition and design document
- `sim/` - Verilator run script

## Running the simulation

### Preferred
```bash
make run
```

### Direct script
```bash
./sim/run_verilator.sh
```

### Optional plusargs
```bash
./sim/run_verilator.sh +SEED=12345 +N_AES_RANDOM=16 +N_VL_RANDOM=24
```

## What the regression testing does

The shipped regression covers:

- NIST AES-128 known-answer encryption
- Directed variable-VL ISA checks (`VL = 4, 8, 12, 16`)
- Random AES-128 encryptions with random plaintext/key pairs
- Random constrained instruction streams for the four custom VAES instructions
- AXI4-Stream backpressure on the result channel
- Self-checking scoreboard comparisons against a bit-accurate reference model class
- SVA checks for AXI hold behavior and internal control-state legality

## Notes

- The reference model is used only in the testbench scoreboard / sequence generation flow. It is not instantiated as a pipeline stage.
- The legal vector lengths in this implementation are `4, 8, 12, 16` bytes to preserve AES column granularity.
- This revision also removes the Verilator 5.046 warnings previously caused by unused packet-reserved bits, unused helper-function bit slices, unused unary-unit ports, and mixed synchronous/asynchronous use of the testbench reset.
