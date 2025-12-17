// =============================================================================
// File: tb_processor.v
// Description: Testbench for Simulation
// =============================================================================
`timescale 1ns / 1ps

module tb_processor;

    reg clk;
    reg reset;
    wire [7:0] result_out;

    // Connect the Testbench to your Processor
    processor_top dut (
        .clk(clk),
        .reset(reset),
        .result_out(result_out)
    );

    // Generate a 100MHz Clock (flips every 5ns)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // The Simulation Sequence
    initial begin
        // 1. Start in Reset (hold for 20ns)
        reset = 1;
        #20;
        
        // 2. Release Reset (Processor starts running!)
        reset = 0;
        
        // 3. Let it run for 500ns (enough for our test program)
        #500;
        
        // 4. Stop
        $stop;
    end

endmodule