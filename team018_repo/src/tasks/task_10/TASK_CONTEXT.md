# Task 10 - Memory-Mapped I/O

Design a command-stream controller for a small memory-mapped system. The peripherals are two register banks, a serial-in shift register, a latch, a timer, and a read-only control/status register.

Decode 16-bit commands, perform the associated reads and writes, advance the timer, and finally return the value selected through the hidden-address mechanism.

Source: `material_hackathon/10_Memory_Mapped.pdf`.
