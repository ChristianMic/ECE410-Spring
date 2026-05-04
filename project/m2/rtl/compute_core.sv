// =============================================================================
// compute_core.sv
// Comparator tree for MaxPool2D forward pass (SystemVerilog)
//
// Description:
//   Accepts a 2x2 window of 16-bit fixed-point values and finds the maximum
//   using a 2-stage comparator tree. Processes one 2x2 window per operation.
//   Outputs the maximum value and a 4-bit one-hot mask indicating which
//   element was the maximum (used by the backward pass MAC unit).
//
// Fixed-point format: Q8.8 (8 integer bits, 8 fractional bits), signed
//
// Latency: 2 clock cycles from valid_in to valid_out
//
// Ports:
//   clk       - System clock
//   rst_n     - Active low synchronous reset
//   valid_in  - Input data valid strobe
//   a         - Top-left element     [row 0, col 0]
//   b         - Top-right element    [row 0, col 1]
//   c         - Bottom-left element  [row 1, col 0]
//   d         - Bottom-right element [row 1, col 1]
//   max_out   - Maximum value of the 2x2 window
//   mask_out  - 4-bit one-hot mask indicating which element was max
//               bit 0 = a, bit 1 = b, bit 2 = c, bit 3 = d
//   valid_out - Output valid strobe (asserted 2 cycles after valid_in)
// =============================================================================

module compute_core #(
    parameter int DATA_WIDTH = 16   // 16-bit fixed-point Q8.8
)(
    input  logic                        clk,
    input  logic                        rst_n,

    // Input interface
    input  logic                        valid_in,
    input  logic signed [DATA_WIDTH-1:0] a,  // row 0, col 0
    input  logic signed [DATA_WIDTH-1:0] b,  // row 0, col 1
    input  logic signed [DATA_WIDTH-1:0] c,  // row 1, col 0
    input  logic signed [DATA_WIDTH-1:0] d,  // row 1, col 1

    // Output interface
    output logic signed [DATA_WIDTH-1:0] max_out,
    output logic [3:0]                   mask_out,
    output logic                         valid_out
);

    // -------------------------------------------------------------------------
    // Stage 1 registers: compare pairs (a vs b) and (c vs d) in parallel
    // -------------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] s1_max_ab;  // max(a, b)
    logic signed [DATA_WIDTH-1:0] s1_max_cd;  // max(c, d)
    logic [1:0]                   s1_sel_ab;  // 2'b01 = a won, 2'b10 = b won
    logic [1:0]                   s1_sel_cd;  // 2'b01 = c won, 2'b10 = d won
    logic                         s1_valid;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            s1_max_ab <= '0;
            s1_max_cd <= '0;
            s1_sel_ab <= 2'b00;
            s1_sel_cd <= 2'b00;
            s1_valid  <= 1'b0;
        end else begin
            s1_valid <= valid_in;

            // Compare a vs b
            if (a >= b) begin
                s1_max_ab <= a;
                s1_sel_ab <= 2'b01;  // a won
            end else begin
                s1_max_ab <= b;
                s1_sel_ab <= 2'b10;  // b won
            end

            // Compare c vs d
            if (c >= d) begin
                s1_max_cd <= c;
                s1_sel_cd <= 2'b01;  // c won
            end else begin
                s1_max_cd <= d;
                s1_sel_cd <= 2'b10;  // d won
            end
        end
    end

    // -------------------------------------------------------------------------
    // Stage 2: compare stage 1 winners to find overall max, generate mask
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            max_out   <= '0;
            mask_out  <= 4'b0000;
            valid_out <= 1'b0;
        end else begin
            valid_out <= s1_valid;

            if (s1_max_ab >= s1_max_cd) begin
                // Winner is from top row (a or b)
                max_out <= s1_max_ab;
                unique case (s1_sel_ab)
                    2'b01:   mask_out <= 4'b0001;  // a was max
                    2'b10:   mask_out <= 4'b0010;  // b was max
                    default: mask_out <= 4'b0001;
                endcase
            end else begin
                // Winner is from bottom row (c or d)
                max_out <= s1_max_cd;
                unique case (s1_sel_cd)
                    2'b01:   mask_out <= 4'b0100;  // c was max
                    2'b10:   mask_out <= 4'b1000;  // d was max
                    default: mask_out <= 4'b0100;
                endcase
            end
        end
    end

endmodule
