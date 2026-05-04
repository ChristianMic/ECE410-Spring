// =============================================================================
// tb_axi4_stream_interface.sv
// Testbench for axi4_stream_interface.sv (SystemVerilog)
//
// Description:
//   Tests AXI4 Stream interface-specific behavior including:
//     1. tready/tvalid handshaking - s_axis_tready deasserts while processing
//     2. Backpressure - m_axis_tready deasserted, output held until accepted
//     3. tlast assertion - verified with output word and deasserts after
//     4. Back-to-back transfers - no gap between transactions
//     5. Reset during transfer - rst_n asserted mid-transaction
//
// Data packing (32-bit AXI4 Stream bus):
//   Word 0: [31:16] = b, [15:0] = a   (top row)
//   Word 1: [31:16] = d, [15:0] = c   (bottom row)
//   Output: [19:16] = mask, [15:0]    = max
//
// Fixed-point Q8.8 encoding:
//   1.0 -> 16'd256, 2.0 -> 16'd512, 3.0 -> 16'd768, 4.0 -> 16'd1024
// =============================================================================

`timescale 1ns/1ps

module tb_axi4_stream_interface;

    // -------------------------------------------------------------------------
    // Parameters
    // -------------------------------------------------------------------------
    parameter int DATA_WIDTH = 16;
    parameter int AXIS_WIDTH = 32;
    parameter int CLK_PERIOD = 10;  // 10ns = 100MHz

    // -------------------------------------------------------------------------
    // DUT signals
    // -------------------------------------------------------------------------
    logic                   clk;
    logic                   rst_n;
    logic [AXIS_WIDTH-1:0]  s_axis_tdata;
    logic                   s_axis_tvalid;
    logic                   s_axis_tready;
    logic                   s_axis_tlast;
    logic [AXIS_WIDTH-1:0]  m_axis_tdata;
    logic                   m_axis_tvalid;
    logic                   m_axis_tready;
    logic                   m_axis_tlast;

    // -------------------------------------------------------------------------
    // Test tracking
    // -------------------------------------------------------------------------
    int test_num;
    int pass_count;
    int fail_count;

    // -------------------------------------------------------------------------
    // DUT instantiation
    // -------------------------------------------------------------------------
    axi4_stream_interface #(
        .DATA_WIDTH(DATA_WIDTH),
        .AXIS_WIDTH(AXIS_WIDTH)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .s_axis_tdata   (s_axis_tdata),
        .s_axis_tvalid  (s_axis_tvalid),
        .s_axis_tready  (s_axis_tready),
        .s_axis_tlast   (s_axis_tlast),
        .m_axis_tdata   (m_axis_tdata),
        .m_axis_tvalid  (m_axis_tvalid),
        .m_axis_tready  (m_axis_tready),
        .m_axis_tlast   (m_axis_tlast)
    );

    // -------------------------------------------------------------------------
    // Clock generation
    // -------------------------------------------------------------------------
    initial clk = 0;
    always #(CLK_PERIOD/2) clk = ~clk;

    // -------------------------------------------------------------------------
    // Task: apply reset and wait until interface is ready to accept data
    // -------------------------------------------------------------------------
    task automatic apply_reset();
        rst_n         <= 1'b0;
        s_axis_tdata  <= '0;
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
        m_axis_tready <= 1'b0;
        repeat(5) @(posedge clk);
        rst_n <= 1'b1;
        // Wait until tready asserts before returning —
        // state machine takes a couple of cycles to reach RECV_W0
        @(posedge clk);
        while (!s_axis_tready) @(posedge clk);
        @(posedge clk); // one extra settling cycle
    endtask

    // -------------------------------------------------------------------------
    // Task: send two AXI words (one 2x2 window)
    // Waits for tready before asserting tvalid on each word
    // -------------------------------------------------------------------------
    task automatic send_window(
        input logic signed [DATA_WIDTH-1:0] a, b, c, d
    );
        // Wait for tready before sending word 0
        while (!s_axis_tready) @(posedge clk);

        // Send Word 0: {b, a} top row
        s_axis_tdata  <= {b, a};
        s_axis_tvalid <= 1'b1;
        s_axis_tlast  <= 1'b0;
        @(posedge clk);

        // Wait for tready before sending word 1
        while (!s_axis_tready) @(posedge clk);

        // Send Word 1: {d, c} bottom row
        s_axis_tdata  <= {d, c};
        s_axis_tvalid <= 1'b1;
        s_axis_tlast  <= 1'b1;
        @(posedge clk);

        // Deassert valid
        s_axis_tvalid <= 1'b0;
        s_axis_tlast  <= 1'b0;
    endtask

    // -------------------------------------------------------------------------
    // Main test sequence
    // -------------------------------------------------------------------------
    initial begin
        rst_n         = 1'b0;
        s_axis_tdata  = '0;
        s_axis_tvalid = 1'b0;
        s_axis_tlast  = 1'b0;
        m_axis_tready = 1'b0;
        test_num      = 0;
        pass_count    = 0;
        fail_count    = 0;

        apply_reset();

        $display("==============================================");
        $display(" axi4_stream_interface Testbench");
        $display("==============================================");

        // ------------------------------------------------------------------
        // Test 1: tready/tvalid handshaking
        // Verify s_axis_tready deasserts while processing and reasserts after
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: tready/tvalid handshaking ---", test_num);
        begin
            logic tready_deasserted;
            tready_deasserted = 1'b0;

            // Send word 0
            while (!s_axis_tready) @(posedge clk);
            s_axis_tdata  <= {16'd512, 16'd256};
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= 1'b0;
            @(posedge clk);

            // Send word 1
            while (!s_axis_tready) @(posedge clk);
            s_axis_tdata  <= {16'd1024, 16'd768};
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= 1'b1;
            @(posedge clk);
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;

            // Monitor tready deassertion while waiting for result
            m_axis_tready <= 1'b0;
            repeat(10) begin
                @(posedge clk);
                if (!s_axis_tready) tready_deasserted = 1'b1;
            end

            // Accept result
            m_axis_tready <= 1'b1;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);
            @(posedge clk);
            m_axis_tready <= 1'b0;

            // Wait for tready to reassert
            repeat(5) @(posedge clk);

            if (tready_deasserted && s_axis_tready) begin
                $display("  PASS: s_axis_tready deasserted during processing and reasserted after");
                pass_count++;
            end else begin
                $display("  FAIL: tready_deasserted=%0b, final s_axis_tready=%0b",
                          tready_deasserted, s_axis_tready);
                fail_count++;
            end
        end

        repeat(3) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 2: Backpressure
        // Hold m_axis_tready low and verify m_axis_tvalid stays asserted
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: Backpressure (m_axis_tready held low) ---", test_num);
        begin
            logic valid_held;
            valid_held = 1'b1;

            send_window(16'd256, 16'd512, 16'd768, 16'd1024);

            // Wait for result but hold tready low
            m_axis_tready <= 1'b0;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);

            // Verify tvalid stays high for several cycles
            repeat(5) begin
                @(posedge clk);
                if (!m_axis_tvalid) valid_held = 1'b0;
            end

            // Now accept
            m_axis_tready <= 1'b1;
            @(posedge clk);
            m_axis_tready <= 1'b0;
            repeat(3) @(posedge clk);

            if (valid_held) begin
                $display("  PASS: m_axis_tvalid held high during backpressure");
                pass_count++;
            end else begin
                $display("  FAIL: m_axis_tvalid dropped before m_axis_tready asserted");
                fail_count++;
            end
        end

        repeat(3) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 3: tlast assertion
        // Verify tlast asserts with tvalid and deasserts after acceptance
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: tlast assertion ---", test_num);
        begin
            logic tlast_with_valid;
            logic tlast_after_accept;

            send_window(16'd1024, 16'd768, 16'd512, 16'd256);

            m_axis_tready <= 1'b0;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);

            // Check tlast is asserted together with tvalid
            tlast_with_valid = m_axis_tlast;

            // Accept transfer
            m_axis_tready <= 1'b1;
            @(posedge clk);
            m_axis_tready <= 1'b0;
            @(posedge clk);

            // Check tlast deasserts after acceptance
            tlast_after_accept = !m_axis_tlast;
            repeat(3) @(posedge clk);

            if (tlast_with_valid && tlast_after_accept) begin
                $display("  PASS: tlast asserted with tvalid and deasserted after acceptance");
                pass_count++;
            end else begin
                $display("  FAIL: tlast_with_valid=%0b tlast_after_accept=%0b",
                          tlast_with_valid, tlast_after_accept);
                fail_count++;
            end
        end

        repeat(3) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 4: Back-to-back transfers
        // Send two windows with no gap and verify both results correct
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: Back-to-back transfers ---", test_num);
        begin
            logic signed [DATA_WIDTH-1:0] result1_max, result2_max;
            logic [3:0] result1_mask, result2_mask;

            // Send first window: max = d = 4.0, mask = 4'b1000
            send_window(16'd256, 16'd512, 16'd768, 16'd1024);

            m_axis_tready <= 1'b1;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);
            result1_max  = m_axis_tdata[DATA_WIDTH-1:0];
            result1_mask = m_axis_tdata[DATA_WIDTH+3:DATA_WIDTH];
            m_axis_tready <= 1'b0;
            @(posedge clk);

            // Immediately send second window: max = a = 4.0, mask = 4'b0001
            send_window(16'd1024, 16'd768, 16'd512, 16'd256);

            m_axis_tready <= 1'b1;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);
            result2_max  = m_axis_tdata[DATA_WIDTH-1:0];
            result2_mask = m_axis_tdata[DATA_WIDTH+3:DATA_WIDTH];
            m_axis_tready <= 1'b0;
            repeat(3) @(posedge clk);

            if (result1_max === 16'd1024 && result1_mask === 4'b1000 &&
                result2_max === 16'd1024 && result2_mask === 4'b0001) begin
                $display("  PASS: both back-to-back results correct");
                $display("        Result 1: max=%0d mask=4'b%04b", $signed(result1_max), result1_mask);
                $display("        Result 2: max=%0d mask=4'b%04b", $signed(result2_max), result2_mask);
                pass_count++;
            end else begin
                $display("  FAIL: Result 1: max=%0d (exp 1024) mask=4'b%04b (exp 4'b1000)",
                          $signed(result1_max), result1_mask);
                $display("        Result 2: max=%0d (exp 1024) mask=4'b%04b (exp 4'b0001)",
                          $signed(result2_max), result2_mask);
                fail_count++;
            end
        end

        repeat(3) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 5: Reset during transfer - outputs clear correctly
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: Reset during transfer (outputs clear) ---", test_num);
        begin
            logic outputs_cleared;

            // Send word 0 then immediately reset
            while (!s_axis_tready) @(posedge clk);
            s_axis_tdata  <= {16'd512, 16'd256};
            s_axis_tvalid <= 1'b1;
            s_axis_tlast  <= 1'b0;
            @(posedge clk);

            // Assert reset mid-transaction
            rst_n         <= 1'b0;
            s_axis_tvalid <= 1'b0;
            s_axis_tlast  <= 1'b0;
            repeat(3) @(posedge clk);

            // Check outputs cleared during reset
            outputs_cleared = (!m_axis_tvalid && !m_axis_tlast);

            if (outputs_cleared) begin
                $display("  PASS: outputs cleared during reset");
                pass_count++;
            end else begin
                $display("  FAIL: outputs not cleared (tvalid=%0b tlast=%0b)",
                          m_axis_tvalid, m_axis_tlast);
                fail_count++;
            end

            // Release reset and wait for tready before next test
            rst_n <= 1'b1;
            @(posedge clk);
            while (!s_axis_tready) @(posedge clk);
            @(posedge clk);
        end

        repeat(3) @(posedge clk);

        // ------------------------------------------------------------------
        // Test 6: Reset recovery - interface completes normal transaction
        // ------------------------------------------------------------------
        test_num++;
        $display("\n--- Test %0d: Reset recovery (normal transaction after reset) ---", test_num);
        begin
            logic signed [DATA_WIDTH-1:0] got_max;
            logic [3:0] got_mask;

            send_window(16'd256, 16'd512, 16'd768, 16'd1024);
            m_axis_tready <= 1'b1;
            @(posedge clk);
            while (!m_axis_tvalid) @(posedge clk);
            got_max  = m_axis_tdata[DATA_WIDTH-1:0];
            got_mask = m_axis_tdata[DATA_WIDTH+3:DATA_WIDTH];
            m_axis_tready <= 1'b0;
            repeat(3) @(posedge clk);

            if (got_max === 16'd1024 && got_mask === 4'b1000) begin
                $display("  PASS: interface recovered correctly after reset");
                pass_count++;
            end else begin
                $display("  FAIL: post-reset: max=%0d (exp 1024) mask=4'b%04b (exp 4'b1000)",
                          $signed(got_max), got_mask);
                fail_count++;
            end
        end

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
        #100000;
        $display("TIMEOUT: simulation exceeded 100us");
        $finish;
    end

    // -------------------------------------------------------------------------
    // VCD dump for GTKWave
    // -------------------------------------------------------------------------
    initial begin
        $dumpfile("tb_axi4_stream_interface.vcd");
        $dumpvars(0, tb_axi4_stream_interface);
    end

endmodule
