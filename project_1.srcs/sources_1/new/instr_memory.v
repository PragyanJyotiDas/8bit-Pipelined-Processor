// =============================================================================
// File: instr_memory.v
// Description: ROM storing the Evaluation Program
// =============================================================================
module instr_memory (
    input  wire [7:0]  addr,
    output wire [15:0] instr
);

    reg [15:0] rom [255:0];
    integer i;

    // Read Logic
    assign instr = rom[addr];

    initial begin
        // Init to NOP
        for (i = 0; i < 256; i = i + 1)
            rom[i] = 16'h0000;

        // --- THE PROGRAM ---
        // 1. Load Imm: R1 = 10
        rom[0] = 16'b1000_001_000_001010; 
        // 2. Load Imm: R2 = 5
        rom[1] = 16'b1000_010_000_000101; 
        // 3. ADD: R3 = R1 + R2 (Should be 15)
        rom[2] = 16'b0001_011_001_010_000; 
        // 4. STORE: MEM[20] = R3
        rom[3] = 16'b0111_000_011_010100; 
        // 5. LOAD: R4 = MEM[20] (Should be 15)
        rom[4] = 16'b0110_100_000_010100; 
        // 6. BEQ: If R3 == R4, Jump forward (skip next instr)
        rom[5] = 16'b1001_011_000000001; 
        // 7. (Skipped if branch works) R5 = 255
        rom[6] = 16'b1000_101_000_111111; 
        // 8. Target: R6 = 170 (Success)
        rom[7] = 16'b1000_110_000_101010; 
        // 9. Jump Loop (Stop here)
        rom[8] = 16'b1010_000_000001000; 
    end

endmodule