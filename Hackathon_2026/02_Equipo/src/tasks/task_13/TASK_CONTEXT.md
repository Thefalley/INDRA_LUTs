# Task 13 - NCO

Generate exactly 2048 waveform samples from two configuration words. The first control defines a power-of-two number of periods; the second selects sine, triangle, or rectangle.

Sine output spans signed 16-bit amplitude, while triangle and rectangle use the non-negative range. The final generated sample must assert `o_last`.

Source: `hackathon/2026/material/13_NCO.pdf`.
