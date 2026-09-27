#!/usr/bin/env bash
set -euo pipefail
cd /home/team018/ref_task8/sw
mb=/opt/tools/Xilinx/2025.2/Vitis/gnu/microblaze/lin/bin
bsp=/home/team018/task8_latency_review/sw/workspace/platform/export/platform/sw/standalone_microblaze_0
linker=/home/team018/task8_latency_review/sw/workspace/app/src/lscript.ld
mkdir -p build
"$mb/mb-gcc" -mlittle-endian -mxl-soft-mul -mcpu=v11.0 -DSDT -O2 -g3 -Wall -Wextra \
    -specs="$bsp/Xilinx.spec" -I"$bsp/include" -c workspace/app/src/main.c -o build/main.o
"$mb/mb-gcc" -mlittle-endian -mxl-soft-mul -mcpu=v11.0 -DSDT -O2 -g3 \
    -specs="$bsp/Xilinx.spec" -Wl,--no-relax -Wl,--gc-sections build/main.o \
    -o build/app.elf -L"$bsp/lib" -Wl,-T,"$linker" -Wl,-Map,build/app.map \
    -Wl,--start-group,-lxilstandalone,-lxiltimer,-lgloss,-lxil,-lgcc,-lc -Wl,--end-group
"$mb/mb-size" build/app.elf
sha256sum workspace/app/src/main.c build/app.elf
