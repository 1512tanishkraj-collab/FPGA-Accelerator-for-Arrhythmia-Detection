`timescale 1ns / 1ps

module conv1d_layer #(
    parameter DATA_WIDTH = 16,
    parameter WEIGHT_WIDTH = 8,
    parameter N_FILTERS = 32,
    parameter KERNEL_SIZE = 5,
    parameter QUANT_SHIFT = 7
)(
    input wire clk,
    input wire rst_n,
    input wire valid_in,
    input wire signed [DATA_WIDTH-1:0] data_in,
    
    output reg valid_out,
    output reg signed [DATA_WIDTH-1:0] data_out,
    output reg [4:0] channel_id
);

    // --- Memories ---
    reg signed [WEIGHT_WIDTH-1:0] mem_weights [0:N_FILTERS*KERNEL_SIZE-1];
    reg signed [DATA_WIDTH-1:0]   mem_biases  [0:N_FILTERS-1];
    
    // UPDATE: Use YOUR absolute path here to prevent "File not found"
    initial begin
        $readmemh("C:/Users/hp/Desktop/ECG_Accelerator_Project/01_Python_Utils/vivado_mem_files/weights.mem", mem_weights);
        $readmemh("C:/Users/hp/Desktop/ECG_Accelerator_Project/01_Python_Utils/vivado_mem_files/biases.mem", mem_biases);
    end

    // --- Logic ---
    reg signed [DATA_WIDTH-1:0] window [0:KERNEL_SIZE-1];
    reg signed [31:0] acc;
    reg [5:0] filter_cnt; 
    reg state;
    integer i;

    localparam IDLE = 1'b0;
    localparam COMPUTE = 1'b1;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            valid_out <= 0;
            data_out <= 0;
            channel_id <= 0;
            filter_cnt <= 0;
            acc <= 0;
            for (i = 0; i < KERNEL_SIZE; i = i + 1) window[i] <= 0;
        end else begin
            case (state)
                IDLE: begin
                    valid_out <= 0;
                    if (valid_in) begin
                        for (i = 0; i < KERNEL_SIZE-1; i = i + 1) 
                            window[i] <= window[i+1];
                        window[KERNEL_SIZE-1] <= data_in;
                        
                        state <= COMPUTE;
                        filter_cnt <= 0;
                    end
                end

                COMPUTE: begin
                    // 1. MAC (Multiply-Accumulate)
                    acc = mem_biases[filter_cnt] + 
                          (window[0] * mem_weights[0*32 + filter_cnt]) +
                          (window[1] * mem_weights[1*32 + filter_cnt]) +
                          (window[2] * mem_weights[2*32 + filter_cnt]) +
                          (window[3] * mem_weights[3*32 + filter_cnt]) +
                          (window[4] * mem_weights[4*32 + filter_cnt]);

                    // 2. ROUNDING FIX
                    // Add 64 (0.5 in Q7) to round to nearest integer
                    if (((acc + 64) >>> QUANT_SHIFT) > 0) 
                        data_out <= (acc + 64) >>> QUANT_SHIFT;
                    else 
                        data_out <= 0;

                    // 3. Output
                    channel_id <= filter_cnt[4:0];
                    valid_out <= 1'b1;

                    // 4. Loop
                    if (filter_cnt == N_FILTERS - 1) state <= IDLE;
                    else filter_cnt <= filter_cnt + 1;
                end
            endcase
        end
    end
endmodule