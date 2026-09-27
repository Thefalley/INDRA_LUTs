# Task 8 - MicroBlaze Software Sorter

## Problem and protocol

Task 8 is software-only. The supplied hardware must remain unchanged. Each transaction is exactly 256 unsigned 32-bit words (1024 bytes) on the AXI-Stream path. The result must contain the same 256 words in ascending unsigned order. The scoring target is a latency below 400 us.

The task wrapper feeds the external stream into the input FIFO and external AXI DMA S2MM channel. Software stores the packet in the shared AXI BRAM at `0xC0000000`, sorts it, then uses the external AXI DMA MM2S channel to emit the result.

## Architecture

`main.c` uses the external AXI DMA registers at `0x41E10000` in simple mode:

- S2MM receives 1024 bytes into `0xC0000000` and software waits for IOC.
- A four-pass, LSD radix sort operates on unsigned bytes. The 1 KiB scratch buffer is at `0xC0000400`; the 256-entry histogram is on the MicroBlaze stack.
- MM2S sends the sorted 1024-byte input buffer and software waits for IOC before accepting the next packet.

The radix sort is stable and has fixed work: four histogram clears, counts, prefix sums, and scatters for 256 elements. It avoids data-dependent quadratic worst cases and ends in the input buffer after its even number of passes.

## Verification status

- MicroBlaze compilation check: `mb-gcc -std=c11 -O3 -Wall -Wextra -Werror -c main.c` passes.
- Full Vitis build: currently blocked before compilation because the local bootstrap fails to generate an SDT platform from `microblaze_system_wrapper.xsa` (`Failed to create platform: platform`). The existing workspace contains no generated `platform` component.
- XSim and isolated synthesis remain pending until the supplied Vitis platform bootstrap succeeds. No latency or resource value has been claimed without those runs.

## Files and constraints

- Functional software: `sw/workspace/app/src/main.c`.
- Build optimization: `sw/workspace/app/src/UserConfig.cmake` sets `-O3` and disables debug information.
- The RTL wrapper, interfaces, block design, and other task files are unchanged.

Source: `hackathon/2026/material/08_Microblaze_Software_Sorter.pdf`.
