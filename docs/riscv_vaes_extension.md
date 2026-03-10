# RISC-V VAES Extension for the AES-128 Vector Coprocessor

## Scope

This document defines the four custom vector instructions implemented by the coprocessor:

- `vaes.sbox.v`
- `vaes.srow.v`
- `vaes.mcol.v`
- `vaes.ark.v`

The coprocessor executes these instructions over a 32-entry vector register file (`v0`..`v31`), with each vector register being 128 bits wide.

The coprocessor is driven through AXI4-Stream packets. The stream carries either:

- a raw 32-bit custom RISC-V instruction word, or
- an auxiliary control/data packet (`LOAD`, `CFG`, `STORE`) used to move vector data in and out of the coprocessor.

The **instruction set** in this file covers the four custom vector instructions. The **stream packet protocol** is documented later in this file because it is required to use the instruction set in simulation.

## Architectural model

### Register file

- 32 vector registers
- Each vector register is 128 bits wide
- Register names: `v0` to `v31`

### Vector length (`VL`)

This implementation supports AES-oriented vector lengths of:

- `VL = 4`
- `VL = 8`
- `VL = 12`
- `VL = 16`

`VL` is expressed in **bytes** and is configured through the AXI4-Stream `CFG` packet.

The restriction to multiples of 4 preserves AES column granularity:

- `VL = 4`  -> 1 active AES column
- `VL = 8`  -> 2 active AES columns
- `VL = 12` -> 3 active AES columns
- `VL = 16` -> 4 active AES columns (full AES-128 state)

Inactive bytes are preserved from the `vs1` source operand.

## Instruction encoding

All four instructions use the same custom R-type encoding under opcode `custom-0` (`0b0001011`).

### 32-bit format

| Bits   | Field   | Meaning |
|--------|---------|---------|
| 31:26  | `funct6`| Operation selector |
| 25     | `vm`    | Must be `1` in this implementation |
| 24:20  | `vs2`   | Source vector register 2 |
| 19:15  | `vs1`   | Source vector register 1 |
| 14:12  | `funct3`| Must be `000` |
| 11:7   | `vd`    | Destination vector register |
| 6:0    | `opcode`| `0001011` (`custom-0`) |

### Common fixed fields

- `opcode = 7'b0001011`
- `funct3 = 3'b000`
- `vm = 1'b1`

## Instruction definitions

### 1) `vaes.sbox.v`

**Assembly**

```text
vaes.sbox.v vd, vs1
```

**Binary encoding**

- `funct6 = 6'b000000`
- `vs2 = 5'b00000` (ignored)
- `vs1 = source register`
- `vd  = destination register`

**Operation**

For each active byte `i < VL`:

```text
vd[i] = AES_SBOX(vs1[i])
```

For each inactive byte `i >= VL`:

```text
vd[i] = vs1[i]
```

**Notes**

- This implements the AES `SubBytes` transform.
- In hardware, the execute stage contains a dedicated parallel byte-substitution unit.
- In the implementation, this operation is modeled as a **2-cycle execute-stage instruction**.

---

### 2) `vaes.srow.v`

**Assembly**

```text
vaes.srow.v vd, vs1
```

**Binary encoding**

- `funct6 = 6'b000001`
- `vs2 = 5'b00000` (ignored)
- `vs1 = source register`
- `vd  = destination register`

**Operation**

`vaes.srow.v` performs AES `ShiftRows` across the active columns only.

If `VL = 4 * C`, then the active portion contains `C` AES columns.

For each AES row `r`:

- row `0`: rotate left by `0`
- row `1`: rotate left by `1`
- row `2`: rotate left by `2`
- row `3`: rotate left by `3`

The rotation is taken modulo the number of active columns `C`.

Inactive bytes are copied from `vs1`.

**Notes**

- `VL` must be one of `4, 8, 12, 16`.
- This is a single-cycle execute-stage operation in this implementation.

---

### 3) `vaes.mcol.v`

**Assembly**

```text
vaes.mcol.v vd, vs1
```

**Binary encoding**

- `funct6 = 6'b000010`
- `vs2 = 5'b00000` (ignored)
- `vs1 = source register`
- `vd  = destination register`

**Operation**

For each active AES column:

```text
vd[col] = AES_MixColumns(vs1[col])
```

Each column is transformed independently using the standard AES matrix over GF(2^8):

```text
[02 03 01 01]
[01 02 03 01]
[01 01 02 03]
[03 01 01 02]
```

Inactive bytes are copied from `vs1`.

**Notes**

- The execute stage contains a dedicated parallel MixColumns unit.
- In the implementation, this operation is modeled as a **2-cycle execute-stage instruction**.

---

### 4) `vaes.ark.v`

**Assembly**

```text
vaes.ark.v vd, vs1, vs2
```

**Binary encoding**

- `funct6 = 6'b000011`
- `vs2 = second source register`
- `vs1 = first source register`
- `vd  = destination register`

**Operation**

For each active byte `i < VL`:

```text
vd[i] = vs1[i] XOR vs2[i]
```

For each inactive byte `i >= VL`:

```text
vd[i] = vs1[i]
```

**Notes**

- This implements the AES `AddRoundKey` step.
- This is a single-cycle execute-stage operation in this implementation.

---

## Encodings summary table

| Instruction     | `funct6`  | Operands            | Execute latency |
|----------------|-----------|---------------------|-----------------|
| `vaes.sbox.v`  | `000000`  | `vd, vs1`           | 2 cycles |
| `vaes.srow.v`  | `000001`  | `vd, vs1`           | 1 cycle |
| `vaes.mcol.v`  | `000010`  | `vd, vs1`           | 2 cycles |
| `vaes.ark.v`   | `000011`  | `vd, vs1, vs2`      | 1 cycle |

## Byte ordering and state mapping

The 128-bit vector is interpreted as 16 bytes in big-endian textual order:

```text
byte0 byte1 byte2 ... byte15
```

Those bytes are mapped into the AES state in the usual column-major form:

```text
state[0,0] = byte0   state[0,1] = byte4   state[0,2] = byte8   state[0,3] = byte12
state[1,0] = byte1   state[1,1] = byte5   state[1,2] = byte9   state[1,3] = byte13
state[2,0] = byte2   state[2,1] = byte6   state[2,2] = byte10  state[2,3] = byte14
state[3,0] = byte3   state[3,1] = byte7   state[3,2] = byte11  state[3,3] = byte15
```

This mapping matches the standard AES-128 test vector:

- plaintext: `00112233445566778899aabbccddeeff`
- key: `000102030405060708090a0b0c0d0e0f`
- ciphertext: `69c4e0d86a7b0430d8cdb78070b4c55a`

## AXI4-Stream packet protocol used by the testbench

The coprocessor uses one AXI4-Stream **slave** input for instructions and data, and one AXI4-Stream **master** output for result packets.

### Input stream width

- `TDATA` width: **256 bits**
- `TLAST`: always `1` for each packet

### Input packet format

| Bits      | Field      | Description |
|-----------|------------|-------------|
| 255:248   | `pkt_type` | Packet kind |
| 247:216   | `word0`    | Raw 32-bit instruction word for `PKT_INST` |
| 215:211   | `reg_idx`  | Register index for `LOAD` / `STORE` |
| 210:206   | `vl`       | Vector length for `CFG` |
| 205:128   | reserved   | Reserved / zero |
| 127:0     | `payload`  | 128-bit vector payload for `LOAD` |

### Packet kinds

| `pkt_type` | Meaning |
|-----------:|---------|
| `0x01`     | `LOAD`  |
| `0x02`     | `INST`  |
| `0x03`     | `CFG`   |
| `0x04`     | `STORE` |

### Packet usage

#### `LOAD`
Writes `payload` into `v[reg_idx]`.

#### `INST`
Carries one raw 32-bit custom VAES instruction in `word0`.

#### `CFG`
Sets `VL` to the value in the `vl` field.

#### `STORE`
Reads `v[reg_idx]` and returns it on the output AXI4-Stream master interface.

## Example AES-128 instruction sequence

```text
CFG VL 16
LOAD V0 00112233445566778899aabbccddeeff
LOAD V1 000102030405060708090a0b0c0d0e0f
...
INST vaes.ark.v V0 V0 V1
INST vaes.sbox.v V0 V0
INST vaes.srow.v V0 V0
INST vaes.mcol.v V0 V0
...
STORE V0
```

## Assembly-form reference

### Unary instructions

```text
vaes.sbox.v vd, vs1
vaes.srow.v vd, vs1
vaes.mcol.v vd, vs1
```

### Binary instruction

```text
vaes.ark.v vd, vs1, vs2
```

## Compliance notes for this deliverable

- The pipeline is a normal 5-stage `IF / ID / EX / MEM / WB` design.
- The reference model is used only in the testbench and scoreboard.
- Verilator is the primary simulator targeted by this package.
