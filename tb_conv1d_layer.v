`timescale 1ns / 1ps

module tb_conv1d_layer();

    // Inputs/Outputs
    reg clk, rst_n, valid_in;
    reg signed [15:0] data_in;
    wire valid_out;
    wire signed [15:0] data_out;
    wire [4:0] channel_id;

    // Memories
    reg signed [15:0] inputs_mem [0:500];  
    reg signed [15:0] golden_mem [0:10000]; 
    
    // Variables
    integer input_idx = 0;
    integer check_idx = 0;
    integer errors = 0;
    integer ignore_cnt = 0; // NEW: Counter to skip warm-up
    
    // DUT
    conv1d_layer uut (
        .clk(clk), .rst_n(rst_n),
        .valid_in(valid_in), .data_in(data_in),
        .valid_out(valid_out), .data_out(data_out), .channel_id(channel_id)
    );

    // Clock
    always #5 clk = ~clk; 

    initial begin
        // Load Files (Update paths if needed, or rely on Project settings)
        $readmemh("C:/Users/hp/Desktop/ECG_Accelerator_Project/01_Python_Utils/vivado_mem_files/inputs.mem", inputs_mem);
        $readmemh("C:/Users/hp/Desktop/ECG_Accelerator_Project/01_Python_Utils/vivado_mem_files/golden.mem", golden_mem);

        // Reset
        clk = 0; rst_n = 0; valid_in = 0; data_in = 0;
        #100 rst_n = 1; 
        #20;

        $display("--- SIMULATION START ---");

        // Feed samples
        for (input_idx = 0; input_idx < 200; input_idx = input_idx + 1) begin
            @(posedge clk);
            data_in <= inputs_mem[input_idx];
            valid_in <= 1;
            
            @(posedge clk);
            valid_in <= 0;
            
            repeat(34) @(posedge clk);
        end
        
        #500;
        $display("------------------------------------------------");
        if (errors == 0) $display("RESULT: PASS (PERFECT MATCH)");
        else $display("RESULT: FAIL (%d Mismatches)", errors);
        $stop;
    end

    // Automatic Checker with Warm-Up Skip
    always @(posedge clk) begin
        if (valid_out) begin
            // We must skip the first 4 bursts (Warm-up period)
            // 4 samples * 32 filters = 128 outputs to ignore.
            if (ignore_cnt < 128) begin
                ignore_cnt = ignore_cnt + 1;
            end 
            else begin
                // Now we compare
                if (data_out !== golden_mem[check_idx]) begin
                    $display("[ERROR] Time %t | Filter %d | Expected %d | Got %d", 
                             $time, channel_id, golden_mem[check_idx], data_out);
                    errors = errors + 1;
                end
                check_idx = check_idx + 1;
            end
        end
    end

endmodule