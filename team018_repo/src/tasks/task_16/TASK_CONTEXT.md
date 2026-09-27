# Task 16 - AXI Stream Compressor/Packer

Pack an AXI4-Stream by removing padding bytes marked invalid by `i_keep`. Valid bytes are compacted toward the least-significant byte lanes without changing their order.

Use the AXI valid/ready handshake, preserve packet boundaries, and set `o_keep` to the number of valid bytes in the final output beat. The valid input masks are `1`, `3`, `7`, and `F`.

Source: `material_hackathon/16_AXI_Stream_Compressor.pdf`.
