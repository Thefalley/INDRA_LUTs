# Task 2 - Self-Calibration (Hitachi)

Reconstruct an estimate of a 16-bit measured signal affected by deterministic, temperature-dependent distortion. The two synchronous input streams are the measured value and an auxiliary temperature value.

Each packet contains 2048 samples. The output requires a 32-bit header followed by one corrected 32-bit result per input sample. The solution belongs in `task_2.vhd` and should preserve packet boundaries.

Source: `hackathon/2026/material/02_Self_Calibration_Hitachi.pdf`.
