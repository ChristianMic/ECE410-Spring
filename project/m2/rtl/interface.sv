// =============================================================================
// axi4_stream_interface.sv
// AXI4 Stream slave/master interface for MaxPool2D chiplet (SystemVerilog)
//
// Description:
//   Wraps compute_core with AXI4 Stream handshaking.
//   - Slave  (RX): receives input data from the host (Intel i5-9600K)
//   - Master (TX): sends results back to the host
//
// Protocol:
//   Implements ARM AMBA AXI4 Stream protocol (IHI0051A).
//   Interface operates at 32-bit bus width, 500MHz clock, 2 GB/s peak bandwidth.
//
// Omitted optional AXI4 Stream signals (not required for this design):
//   TKEEP  - byte qualifier, omitted as all bytes are always valid
//   TSTRB  - byte type qualifier, omitted as all bytes are data bytes
//   TID    - stream identifier, omitted as only one stream is used
//   TDEST  - routing information, omitted as only one destination exists
//
// Transaction format (32-bit words, 16-bit Q8.8 fixed-point values):
//   Slave input (2 words per transaction):
//     Word 0: [31:16] = b (top-right),  [15:0] = a (top-left)
//     Word 1: [31:16] = d (bot-right),  [15:0] = c (bot-left)
//   Master output (1 word per transaction):
//     [31:20] = reserved (zeros)
//     [19:16] = mask_out (4-bit one-hot: bit0=a, bit1=b, bit2=c, bit3=d)
//     [15:0]  = max_out  (16-bit Q8.8 fixed-point maximum value)
//
// Transaction timing diagram (cycle accurate):
//   Cycle 1: Host asserts s_axis_tvalid, sends Word 0 {b,a}
//   Cycle 2: Host asserts s_axis_tvalid, sends Word 1 {d,c}
//            s_axis_tready deasserts - interface stops accepting input
//   Cycle 3: compute_core pipeline stage 1 (compare pairs)
//   Cycle 4: compute_core pipeline stage 2 (find overall max)
//            m_axis_tvalid asserts, result available on m_axis_tdata
//            m_axis_tlast asserts indicating end of output packet
//   Cycle 5: Host asserts m_axis_tready to accept result
//            s_axis_tready reasserts - ready for next transaction
//
//   Total latency:    4 cycles from first input word to output valid
//   Total throughput: 1 window per 4 cycles (no pipelining between windows)
//
// Reset behavior:
//   Active low synchronous reset (rst_n).
//   On reset: state machine returns to RECV_W0, s_axis_tready asserts
//   immediately so host can begin sending data as soon as reset releases.
//   All outputs (m_axis_tvalid, m_axis_tlast, m_axis_tdata) are cleared.
//
// AXI4 Stream compliance notes:
//   - Once m_axis_tvalid is asserted it is held until m_axis_tready is seen,
//     conforming to the AXI4 Stream handshake requirement.
//   - s_axis_tready deasserts during processing to apply backpressure to
//     the host, preventing new data from being accepted mid-computation.
//
// Ports:
//   clk              - System clock (500MHz)
//   rst_n            - Active low synchronous reset
//   s_axis_tdata     - Slave input data (32-bit packed pixel pair)
//   s_axis_tvalid    - Slave input valid
//   s_axis_tready    - Slave ready to accept data (backpressure signal)
//   s_axis_tlast     - Slave end of input packet (asserted on Word 1)
//   m_axis_tdata     - Master output data (32-bit packed result)
//   m_axis_tvalid    - Master output valid
//   m_axis_tready    - Master ready (from downstream host)
//   m_axis_tlast     - Master end of output packet (asserted with result)
// =============================================================================

module axi4_stream_interface #(
    parameter int DATA_WIDTH = 16,
    parameter int AXIS_WIDTH = 32
)(
    input  logic clk,
    input  logic rst_n,

    // AXI4 Stream Slave (RX from host)
    input  logic [AXIS_WIDTH-1:0]  s_axis_tdata,
    input  logic                   s_axis_tvalid,
    output logic                   s_axis_tready,
    input  logic                   s_axis_tlast,

    // AXI4 Stream Master (TX to host)
    output logic [AXIS_WIDTH-1:0]  m_axis_tdata,
    output logic                   m_axis_tvalid,
    input  logic                   m_axis_tready,
    output logic                   m_axis_tlast
);

    // -------------------------------------------------------------------------
    // State machine encoding
    // -------------------------------------------------------------------------
    typedef enum logic [1:0] {
        RECV_W0   = 2'b00,   // Ready to receive word 0: {b, a} top row
        RECV_W1   = 2'b01,   // Ready to receive word 1: {d, c} bottom row
        WAIT_CORE = 2'b10,   // Waiting for compute_core result (2 cycle latency)
        OUTPUT    = 2'b11    // Holding output until downstream accepts
    } state_t;

    state_t state;

    // -------------------------------------------------------------------------
    // Internal signals to/from compute_core
    // -------------------------------------------------------------------------
    logic signed [DATA_WIDTH-1:0] core_a, core_b, core_c, core_d;
    logic                         core_valid_in;
    logic signed [DATA_WIDTH-1:0] core_max_out;
    logic [3:0]                   core_mask_out;
    logic                         core_valid_out;

    // -------------------------------------------------------------------------
    // State machine
    // -------------------------------------------------------------------------
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state         <= RECV_W0;
            s_axis_tready <= 1'b1;   // assert tready immediately on reset release
            core_valid_in <= 1'b0;
            core_a        <= '0;
            core_b        <= '0;
            core_c        <= '0;
            core_d        <= '0;
            m_axis_tvalid <= 1'b0;
            m_axis_tdata  <= '0;
            m_axis_tlast  <= 1'b0;
        end else begin
            core_valid_in <= 1'b0;  // default deassert

            case (state)

                // Receive word 0: top row {b, a}
                RECV_W0: begin
                    s_axis_tready <= 1'b1;
                    m_axis_tvalid <= 1'b0;
                    m_axis_tlast  <= 1'b0;
                    if (s_axis_tvalid && s_axis_tready) begin
                        core_a <= s_axis_tdata[DATA_WIDTH-1:0];
                        core_b <= s_axis_tdata[AXIS_WIDTH-1:DATA_WIDTH];
                        state  <= RECV_W1;
                    end
                end

                // Receive word 1: bottom row {d, c}
                RECV_W1: begin
                    s_axis_tready <= 1'b1;
                    if (s_axis_tvalid && s_axis_tready) begin
                        core_c        <= s_axis_tdata[DATA_WIDTH-1:0];
                        core_d        <= s_axis_tdata[AXIS_WIDTH-1:DATA_WIDTH];
                        core_valid_in <= 1'b1;
                        s_axis_tready <= 1'b0;  // stop accepting until result ready
                        state         <= WAIT_CORE;
                    end
                end

                // Wait for compute_core result (2 cycle pipeline latency)
                WAIT_CORE: begin
                    if (core_valid_out) begin
                        m_axis_tdata  <= {{(AXIS_WIDTH-DATA_WIDTH-4){1'b0}},
                                           core_mask_out,
                                           core_max_out};
                        m_axis_tvalid <= 1'b1;
                        m_axis_tlast  <= 1'b1;
                        state         <= OUTPUT;
                    end
                end

                // Hold output until downstream accepts
                OUTPUT: begin
                    if (m_axis_tvalid && m_axis_tready) begin
                        m_axis_tvalid <= 1'b0;
                        m_axis_tlast  <= 1'b0;
                        s_axis_tready <= 1'b1;  // ready for next transaction
                        state         <= RECV_W0;
                    end
                end

            endcase
        end
    end

    // -------------------------------------------------------------------------
    // Compute core instantiation
    // -------------------------------------------------------------------------
    compute_core #(
        .DATA_WIDTH(DATA_WIDTH)
    ) u_compute_core (
        .clk       (clk),
        .rst_n     (rst_n),
        .valid_in  (core_valid_in),
        .a         (core_a),
        .b         (core_b),
        .c         (core_c),
        .d         (core_d),
        .max_out   (core_max_out),
        .mask_out  (core_mask_out),
        .valid_out (core_valid_out)
    );

endmodule
