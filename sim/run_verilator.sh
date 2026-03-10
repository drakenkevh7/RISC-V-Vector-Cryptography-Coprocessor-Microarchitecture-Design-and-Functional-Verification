#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

if command -v verilator >/dev/null 2>&1; then
    VERILATOR=(verilator)
else
    VERILATOR=(python -m verilator)
fi

"${VERILATOR[@]}" --binary --timing --assert -Wall -Wno-fatal   -Irtl -Itb   rtl/vaes_common_pkg.sv   rtl/vaes_aes_pkg.sv   rtl/vaes_regfile.sv   rtl/vaes_sbox_unit.sv   rtl/vaes_srow_unit.sv   rtl/vaes_mcol_unit.sv   rtl/vaes_ark_unit.sv   rtl/vaes_coproc_top.sv   tb/tb_vaes_pkg.sv   tb/tb_vaes_coproc.sv   --top-module tb_vaes_coproc   -Mdir sim/obj_dir

./sim/obj_dir/Vtb_vaes_coproc "$@"
