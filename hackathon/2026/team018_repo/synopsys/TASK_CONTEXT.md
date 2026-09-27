# Task 4 - Synopsys Frame Extender

Receive a continuous 8 Mbit/s serial stream containing 128-bit frames. Each frame starts with `01001110` and its 120-bit payload contains exactly one `1` bit.

Emit each original frame followed by an 8-bit, MSB-first inverted binary representation of that payload bit position. The design uses the related clocking requirements and must remain within two input frames of latency.

Source: `hackathon/2026/material/04_Frame_Extender_Synopsys.pdf`.
