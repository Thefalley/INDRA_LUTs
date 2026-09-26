# Task 1 - Shifter

Receives two control bytes followed by a packet of 8-bit data. The control selects shift or rotate, left or right, and a 12-bit shift amount.

The output contains the transformed data packet and must mark its final byte with `o_last`. The implementation uses one FSM: it captures the controls, streams output during reception whenever causally possible, and uses a short flush only for pending bytes. Rotate-right must wait for the packet tail because its first output bits depend on it.

Source: `material_hackathon/01_Shifter.pdf`.
