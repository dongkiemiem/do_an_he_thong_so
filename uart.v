module uart #(
    parameter CLK_FREQ  = 27_000_000,
    parameter BAUD_RATE = 115200
)(
    input  wire       clk,
    input  wire       rst_n,

    // =====================================================
    // UART PINS
    // =====================================================

    input  wire       rx,
    output reg        tx,


    // =====================================================
    // TX INTERFACE
    // =====================================================

    input  wire       wr_en,
    input  wire [7:0] din,
    output reg        tx_busy,


    // =====================================================
    // RX INTERFACE
    // =====================================================

    output reg  [7:0] dout,
    output reg        rx_ready
);


    // =====================================================
    // BAUD CLOCK
    // =====================================================

    localparam CLKS_PER_BIT = CLK_FREQ / BAUD_RATE;


    // =====================================================
    // =====================================================
    // UART TRANSMITTER
    // =====================================================
    // =====================================================

    reg [15:0] tx_clk_count;
    reg [3:0]  tx_bit_index;
    reg [9:0]  tx_shift_reg;

    localparam TX_IDLE  = 2'd0;
    localparam TX_START = 2'd1;
    localparam TX_DATA  = 2'd2;
    localparam TX_STOP  = 2'd3;

    reg [1:0] tx_state;


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            tx            <= 1'b1;
            tx_busy       <= 1'b0;

            tx_clk_count  <= 16'd0;
            tx_bit_index  <= 4'd0;
            tx_shift_reg  <= 10'd0;

            tx_state      <= TX_IDLE;

        end

        else begin

            case (tx_state)


                // =================================================
                // IDLE
                // =================================================

                TX_IDLE: begin

                    tx      <= 1'b1;
                    tx_busy <= 1'b0;

                    if (wr_en) begin

                        // Frame:
                        // START + 8 DATA + STOP
                        tx_shift_reg <= {1'b1, din, 1'b0};

                        tx_busy      <= 1'b1;
                        tx_clk_count <= 16'd0;
                        tx_bit_index <= 4'd0;

                        tx_state     <= TX_START;

                    end

                end


                // =================================================
                // START BIT
                // =================================================

                TX_START: begin

                    tx <= 1'b0;

                    if (tx_clk_count < CLKS_PER_BIT - 1) begin

                        tx_clk_count <= tx_clk_count + 16'd1;

                    end

                    else begin

                        tx_clk_count <= 16'd0;
                        tx_state     <= TX_DATA;

                    end

                end


                // =================================================
                // DATA BITS
                // =================================================

                TX_DATA: begin

                    tx <= tx_shift_reg[tx_bit_index + 1];

                    if (tx_clk_count < CLKS_PER_BIT - 1) begin

                        tx_clk_count <= tx_clk_count + 16'd1;

                    end

                    else begin

                        tx_clk_count <= 16'd0;

                        if (tx_bit_index < 4'd7) begin

                            tx_bit_index <= tx_bit_index + 4'd1;

                        end

                        else begin

                            tx_state <= TX_STOP;

                        end

                    end

                end


                // =================================================
                // STOP BIT
                // =================================================

                TX_STOP: begin

                    tx <= 1'b1;

                    if (tx_clk_count < CLKS_PER_BIT - 1) begin

                        tx_clk_count <= tx_clk_count + 16'd1;

                    end

                    else begin

                        tx_clk_count <= 16'd0;
                        tx_busy      <= 1'b0;
                        tx_state     <= TX_IDLE;

                    end

                end


                default: begin

                    tx_state <= TX_IDLE;
                    tx       <= 1'b1;
                    tx_busy  <= 1'b0;

                end

            endcase

        end

    end


    // =====================================================
    // =====================================================
    // UART RECEIVER
    // =====================================================
    // =====================================================


    // Synchronizer
    reg rx_sync_1;
    reg rx_sync_2;


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            rx_sync_1 <= 1'b1;
            rx_sync_2 <= 1'b1;

        end

        else begin

            rx_sync_1 <= rx;
            rx_sync_2 <= rx_sync_1;

        end

    end


    // RX state machine

    localparam RX_IDLE  = 2'd0;
    localparam RX_START = 2'd1;
    localparam RX_DATA  = 2'd2;
    localparam RX_STOP  = 2'd3;

    reg [1:0] rx_state;

    reg [15:0] rx_clk_count;
    reg [3:0]  rx_bit_index;

    reg [7:0] rx_shift_reg;


    always @(posedge clk or negedge rst_n) begin

        if (!rst_n) begin

            rx_state      <= RX_IDLE;

            rx_clk_count  <= 16'd0;
            rx_bit_index  <= 4'd0;

            rx_shift_reg  <= 8'd0;

            dout          <= 8'd0;
            rx_ready      <= 1'b0;

        end

        else begin

            // Mặc định:
            // rx_ready chỉ lên 1 trong 1 clock
            rx_ready <= 1'b0;


            case (rx_state)


                // =============================================
                // IDLE
                // Chờ START BIT
                // =============================================

                RX_IDLE: begin

                    rx_clk_count <= 16'd0;
                    rx_bit_index <= 4'd0;

                    if (rx_sync_2 == 1'b0) begin

                        rx_state <= RX_START;

                    end

                end


                // =============================================
                // START
                // Chờ nửa bit rồi kiểm tra lại
                // =============================================

                RX_START: begin

                    if (rx_clk_count <
                        (CLKS_PER_BIT / 2) - 1) begin

                        rx_clk_count <=
                            rx_clk_count + 16'd1;

                    end

                    else begin

                        rx_clk_count <= 16'd0;

                        // Vẫn LOW => START BIT hợp lệ
                        if (rx_sync_2 == 1'b0) begin

                            rx_state <= RX_DATA;

                        end

                        else begin

                            // Nhiễu
                            rx_state <= RX_IDLE;

                        end

                    end

                end


                // =============================================
                // DATA
                // Nhận 8 bit, LSB trước
                // =============================================

                RX_DATA: begin

                    if (rx_clk_count <
                        CLKS_PER_BIT - 1) begin

                        rx_clk_count <=
                            rx_clk_count + 16'd1;

                    end

                    else begin

                        rx_clk_count <= 16'd0;

                        rx_shift_reg[rx_bit_index]
                            <= rx_sync_2;

                        if (rx_bit_index < 4'd7) begin

                            rx_bit_index <=
                                rx_bit_index + 4'd1;

                        end

                        else begin

                            rx_bit_index <= 4'd0;
                            rx_state <= RX_STOP;

                        end

                    end

                end


                // =============================================
                // STOP BIT
                // =============================================

                RX_STOP: begin

                    if (rx_clk_count <
                        CLKS_PER_BIT - 1) begin

                        rx_clk_count <=
                            rx_clk_count + 16'd1;

                    end

                    else begin

                        rx_clk_count <= 16'd0;

                        // Kiểm tra STOP BIT
                        if (rx_sync_2 == 1'b1) begin

                            dout     <= rx_shift_reg;
                            rx_ready <= 1'b1;

                        end

                        rx_state <= RX_IDLE;

                    end

                end


                default: begin

                    rx_state <= RX_IDLE;

                end

            endcase

        end

    end

endmodule