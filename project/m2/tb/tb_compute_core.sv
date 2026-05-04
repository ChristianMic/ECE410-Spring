// =============================================================================
// tb_compute_core.sv
// Testbench for compute_core.sv (SystemVerilog)
//
// Description:
//   Directly drives the compute_core inputs with known 2x2 window values
//   and checks the max output and mask against expected results.
//
// Fixed-point Q8.8 encoding:
//   To convert a real number to Q8.8: multiply by 256 and round to integer
//   Example: 1.0 -> 256 = 16'd256, 2.0 -> 512 = 16'd512
// =============================================================================

`timescale 1ns/1ps

module tb_compute_core;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter int DATA_WIDTH = 16;
    parameter int CLK_PERIOD = 10;  // 10ns = 100MHz

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                        clk;
    logic                        rst_n;
    logic                        valid_in;
    logic signed [DATA_WIDTH-1:0] a, b, c, d;
    logic signed [DATA_WIDTH-1:0] max_out;
    logic [3:0]                  mask_out;
    logic                        valid_out;

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int test_num;
    int pass_count;
    int fail_count;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    compute_core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (valid_in),
        .a         (a),
        .b         (b),
        .c         (c),
        .d         (d),
        .max_out   (max_out),
        .mask_out  (mask_out),
        .valid_out (valid_out)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: drive inputs for one cycle and wait for result (2 cycle latency)
    // -------------------------------------------------------------------------
    task automatic drive_and_check(
        input logic signed [DATA_WIDTH-1:0] in_a, in_b, in_c, in_d,
        input logic signed [DATA_WIDTH-1:0] exp_max,
        input logic [3:0]                   exp_mask,
        input string                        test_name
    );
        test_num++;
        $display("\n--- Test %0d: %s ---", test_num, test_name);
        $display("  Input: a=%0d b=%0d c=%0d d=%0d (Q8.8 integers)",
                  $signed(in_a), $signed(in_b), $signed(in_c), $signed(in_d));

        // Drive inputs for one clock cycle
        @(posedge clk);
        a        <= in_a;
        b        <= in_b;
        c        <= in_c;
        d        <= in_d;
        valid_in <= 1'b1;

        @(posedge clk);
        valid_in <= 1'b0;

        // Wait for valid_out (2 cycle pipeline latency)
        @(posedge clk);
        while (!valid_out) @(posedge clk);

        // Check result
        if (max_out === exp_max && mask_out === exp_mask) begin
            $display("  PASS: max=%0d (expected %0d), mask=4'b%04b (expected 4'b%04b)",
                      $signed(max_out), $signed(exp_max), mask_out, exp_mask);
            pass_count++;
        end else begin
            $display("  FAIL: max=%0d (expected %0d), mask=4'b%04b (expected 4'b%04b)",
                      $signed(max_out), $signed(exp_max), mask_out, exp_mask);
            fail_count++;
        end

        // Wait a few cycles before next test
        repeat(3) @(posedge clk);

    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        // Initialise signals
        rst_n    = 1'b0;
        valid_in = 1'b0;
        a        = '0;
        b        = '0;
        c        = '0;
        d        = '0;
        test_num   = 0;
        pass_count = 0;
        fail_count = 0;

        // Apply reset for 5 cycles
        repeat(5) @(posedge clk);
        rst_n = 1'b1;
        repeat(2) @(posedge clk);

        $display("==============================================");
        $display(" compute_core Testbench");
        $display("==============================================");

        // ------------------------------------------------------------------
        // Test 1: Ascending values - d is max
        // Window: | 1 | 2 |    Expected max = 4.0, mask = 4'b1000 (d)
        //         | 3 | 4 |
        // ------------------------------------------------------------------
        drive_and_check(
            16'd256, 16'd512, 16'd768, 16'd1024,
            16'd1024, 4'b1000,
            "Ascending values (max=d)"
        );

        // ------------------------------------------------------------------
        // Test 2: Descending values - a is max
        // Window: | 4 | 3 |    Expected max = 4.0, mask = 4'b0001 (a)
        //         | 2 | 1 |
        // ------------------------------------------------------------------
        drive_and_check(
            16'd1024, 16'd768, 16'd512, 16'd256,
            16'd1024, 4'b0001,
            "Descending values (max=a)"
        );

        // ------------------------------------------------------------------
        // Test 3: All equal - a wins tie
        // Window: | 2 | 2 |    Expected max = 2.0, mask = 4'b0001 (a)
        //         | 2 | 2 |
        // ------------------------------------------------------------------
        drive_and_check(
            16'd512, 16'd512, 16'd512, 16'd512,
            16'd512, 4'b0001,
            "All equal (tie -> a wins)"
        );

        // ------------------------------------------------------------------
        // Test 4: Negative values - max is least negative
        // Window: | -1 | -2 |    Expected max = -1.0, mask = 4'b0001 (a)
        //         | -3 | -4 |
        // ------------------------------------------------------------------
        drive_and_check(
            -16'd256, -16'd512, -16'd768, -16'd1024,
            -16'd256, 4'b0001,
            "Negative values (max=a)"
        );

        // ------------------------------------------------------------------
        // Test 5: Mixed positive and negative - b is max
        // Window: | -1 |  3 |    Expected max = 3.0, mask = 4'b0010 (b)
        //         |  1 | -2 |
        // ------------------------------------------------------------------
        drive_and_check(
            -16'd256, 16'd768, 16'd256, -16'd512,
            16'd768, 4'b0010,
            "Mixed positive/negative (max=b)"
        );

        // ------------------------------------------------------------------
        // Test 6: c is max
        // Window: | 1 | 2 |    Expected max = 5.0, mask = 4'b0100 (c)
        //         | 5 | 3 |
        // ------------------------------------------------------------------
        drive_and_check(
            16'd256, 16'd512, 16'd1280, 16'd768,
            16'd1280, 4'b0100,
            "Bottom-left is max (max=c)"
        );

        // ------------------------------------------------------------------
        // Summary
        // ------------------------------------------------------------------
        repeat(5) @(posedge clk);
        $display("\n==============================================");
        $display(" Results: %0d/%0d tests passed", pass_count, test_num);
        if (fail_count == 0)
            $display(" ALL TESTS PASSED");
        else
            $display(" %0d TEST(S) FAILED", fail_count);
        $display("==============================================\n");

        $finish;
    end

    // -------------------------------------------------------------------------
    // Timeout watchdog
    // -------------------------------------------------------------------------
    initial begin
        #50000;
        $display("TIMEOUT: simulation exceeded 50us");
        $finish;
    end

    // -------------------------------------------------------------------------
    // VCD dump for GTKWave
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_compute_core.vcd");
        $dumpvars(0, tb_compute_core);
    end

endmodule
