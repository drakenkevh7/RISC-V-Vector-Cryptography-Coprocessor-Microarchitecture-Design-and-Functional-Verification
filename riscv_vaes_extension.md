# RISC‑V VAES Vector Crypto Extension (Reference)

This repository contains a reference RTL + testbench for a **custom RISC‑V Vector AES (VAES)** coprocessor that accelerates AES‑128 round transformations on 128‑bit vector registers.

The RTL decodes **32‑bit RVV vector instructions** (opcode `0x57`) and implements the following VAES operations:

- `vaes.sbox.v` — SubBytes (AES S‑box on all state bytes)
- `vaes.srow.v` — ShiftRows
- `vaes.mcol.v` — MixColumns
- `vaes.ark.v`  — AddRoundKey (XOR with round key)

## 1. Vector register model

- Vector register file: **32 registers** (`v0`…`v31`)
- Register width: **128 bits** per register
- Each 128‑bit register holds **one AES state** (16 bytes).

### Vector length (VL) in this reference design

Architecturally, RVV normally supplies `VL` via `vsetvl`.  
In this reference coprocessor, `VL` is provided **out‑of‑band** in the AXI‑Stream EXEC command header (see `riscv_vaes_coproc.sv`).

Interpretation in this design:

- `VL` = number of **128‑bit elements** processed.
- A single VAES instruction is decomposed into **VL micro‑ops**, operating on consecutive registers:
  - Element `e` uses:
    - `vd_e  = (vd_base  + e) mod 32`
    - `vs1_e = (vs1_base + e) mod 32`
    - `vs2_e = (vs2_base + e) mod 32`

**Overlap semantics:** Elements are executed **sequentially** (`e = 0 → VL-1`) and updates commit in order.

## 2. Instruction encoding

All VAES ops use the standard RVV opcode:

- `opcode` = `0b1010111` = `0x57`

Field layout (RVV vector “VV” format):

```
31          26 25   24      20 19      15 14   12 11       7 6      0
+--------------+----+----------+----------+-------+----------+--------+
|    funct6    | vm |   vs2    |   vs1    |funct3 |    vd    | opcode |
+--------------+----+----------+----------+-------+----------+--------+
```

- `vm` is accepted but not used for masking in this reference.
- `funct3` is `000` in this reference.

### funct6 allocation

| Instruction     | funct6 (bin) | funct6 (hex) |
|----------------|--------------|--------------|
| `vaes.sbox.v`  | `101000`     | `0x28`       |
| `vaes.srow.v`  | `101001`     | `0x29`       |
| `vaes.mcol.v`  | `101010`     | `0x2A`       |
| `vaes.ark.v`   | `101011`     | `0x2B`       |

## 3. Instruction semantics

### 3.1 `vaes.sbox.v`

**Assembly (conceptual):**
```
vaes.sbox.v vd, vs2
```

**Operation (per element):**
```
vd_e = SubBytes(vs2_e)
```

### 3.2 `vaes.srow.v`

**Assembly (conceptual):**
```
vaes.srow.v vd, vs2
```

**Operation (per element):**
```
vd_e = ShiftRows(vs2_e)
```

### 3.3 `vaes.mcol.v`

**Assembly (conceptual):**
```
vaes.mcol.v vd, vs2
```

**Operation (per element):**
```
vd_e = MixColumns(vs2_e)
```

### 3.4 `vaes.ark.v`

**Assembly (conceptual):**
```
vaes.ark.v vd, vs2, vs1
```

**Operation (per element):**
```
vd_e = vs2_e XOR vs1_e
```

## 4. Notes on byte order

The RTL and testbench treat a 128‑bit value as 16 bytes `b[0..15]`:

- `b[0]`  = bits `[127:120]` (MSB)
- `b[15]` = bits `[7:0]` (LSB)

This matches the typical hex literal view (e.g. `128'h001122...`).

