# Task 3 - Morse

Build a bidirectional transcoder between 7-bit uppercase ASCII and a time-domain Morse bitstream. A dot is one `1`, a dash is three `1`s, symbol gaps are one `0`, letter gaps are three `0`s, and word gaps are seven `0`s.

The first input byte selects the representation: MSB set means Morse input on the LSB; MSB clear means ASCII input. Input and output are byte streams up to 4 KiB and must preserve `valid` and packet-end semantics.

Source: `material_hackathon/03_Morse.pdf`.
