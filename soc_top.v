module soc_top (
    input wire clk,
    input wire rst_n,

    input wire uart_rx,
    output wire uart_tx,

    output wire [5:0] led
);

    // =========================================================
    // 1. RESET DELAY
    // =========================================================

    reg [3:0] reset_cnt = 4'd0;
    wire cpu_rst_n;

    assign cpu_rst_n = &reset_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            reset_cnt <= 4'd0;
        else if (!cpu_rst_n)
            reset_cnt <= reset_cnt + 4'd1;
    end


    // =========================================================
    // 2. PICORV32 MEMORY BUS
    // =========================================================

    wire        mem_valid;
    wire        mem_instr;
    reg         mem_ready;

    wire [31:0] mem_addr;
    wire [31:0] mem_wdata;
    wire [3:0]  mem_wstrb;

    reg [31:0] mem_rdata;


    // =========================================================
    // 3. PICORV32 CPU
    // =========================================================

    picorv32 #(
        .BARREL_SHIFTER(0),
        .COMPRESSED_ISA(0),
        .ENABLE_COUNTERS(0),
        .ENABLE_MUL(0),
        .ENABLE_DIV(0),
        .STACKADDR(32'h00002000)
    ) cpu (
        .clk(clk),
        .resetn(cpu_rst_n),

        .mem_valid(mem_valid),
        .mem_instr(mem_instr),
        .mem_ready(mem_ready),

        .mem_addr(mem_addr),
        .mem_wdata(mem_wdata),
        .mem_wstrb(mem_wstrb),

        .mem_rdata(mem_rdata),

        .trap()
    );


    // =========================================================
    // 4. ADDRESS DECODER
    // =========================================================
    //
    // ROM              0x00000000 - 0x00000FFF
    // RAM              0x00001000 - 0x00001FFF
    //
    // UART TX          0x02000000
    // UART RX DATA     0x02000004
    // UART RX STATUS   0x02000008
    //
    // GPIO LED         0x04000000
    //
    // CNN CONTROL      0x05000000
    // CNN STATUS       0x05000004
    // CNN RESULT       0x05000008
    // CNN INPUT WRITE  0x0500000C
    //
    // BUFFER CONTROL   0x05000010
    // BUFFER READ ADDR 0x05000014
    // BUFFER READ DATA 0x05000018
    // BUFFER COUNT     0x0500001C
    // =========================================================

    wire mem_rom_en;
    wire mem_ram_en;

    wire mem_uart_tx_en;
    wire mem_uart_rx_data_en;
    wire mem_uart_rx_status_en;

    wire mem_led_en;

    wire mem_cnn_ctrl_en;
    wire mem_cnn_status_en;
    wire mem_cnn_result_en;
    wire mem_cnn_input_en;

    wire mem_buffer_ctrl_en;
    wire mem_buffer_addr_en;
    wire mem_buffer_data_en;
    wire mem_buffer_status_en;


    assign mem_rom_en =
        (mem_addr >= 32'h00000000) &&
        (mem_addr <= 32'h00000FFF);

    assign mem_ram_en =
        (mem_addr >= 32'h00001000) &&
        (mem_addr <= 32'h00001FFF);


    // UART
    assign mem_uart_tx_en =
        (mem_addr == 32'h02000000);

    assign mem_uart_rx_data_en =
        (mem_addr == 32'h02000004);

    assign mem_uart_rx_status_en =
        (mem_addr == 32'h02000008);


    // LED
    assign mem_led_en =
        (mem_addr == 32'h04000000);


    // CNN
    assign mem_cnn_ctrl_en =
        (mem_addr == 32'h05000000);

    assign mem_cnn_status_en =
        (mem_addr == 32'h05000004);

    assign mem_cnn_result_en =
        (mem_addr == 32'h05000008);

    assign mem_cnn_input_en =
        (mem_addr == 32'h0500000C);


    // BUFFER
    assign mem_buffer_ctrl_en =
        (mem_addr == 32'h05000010);

    assign mem_buffer_addr_en =
        (mem_addr == 32'h05000014);

    assign mem_buffer_data_en =
        (mem_addr == 32'h05000018);

    assign mem_buffer_status_en =
        (mem_addr == 32'h0500001C);


    // =========================================================
    // 5. ROM
    // =========================================================

    wire [31:0] rom_rdata;

    rom u_rom (
        .addr(mem_addr),
        .rdata(rom_rdata)
    );


    // =========================================================
    // 6. RAM
    // =========================================================

    wire [31:0] ram_rdata;
    wire [3:0] ram_wstrb;

    assign ram_wstrb =
        mem_ram_en ? mem_wstrb : 4'b0000;

    ram u_ram (
        .clk(clk),
        .addr(mem_addr),
        .wdata(mem_wdata),
        .wstrb(ram_wstrb),
        .rdata(ram_rdata)
    );


    // =========================================================
    // 7. UART
    // =========================================================

    reg uart_wr_en;
    wire uart_tx_busy;

    wire [7:0] uart_rx_data;
    wire uart_rx_ready;


    uart #(
        .CLK_FREQ(27_000_000),
        .BAUD_RATE(115200)
    ) u_uart (
        .clk(clk),
        .rst_n(cpu_rst_n),

        .rx(uart_rx),
        .tx(uart_tx),

        // TX
        .wr_en(uart_wr_en),
        .din(mem_wdata[7:0]),
        .tx_busy(uart_tx_busy),

        // RX
        .dout(uart_rx_data),
        .rx_ready(uart_rx_ready)
    );


    // =========================================================
    // 8. UART RX BUFFER
    // =========================================================
    //
    // uart_rx_ready chỉ là xung ngắn.
    // Ta lưu byte vào register để CPU không bị mất dữ liệu.
    //
    // CPU đọc UART RX DATA:
    //     UART_RX_DATA_ADDR = 0x02000004
    //
    // CPU kiểm tra UART RX STATUS:
    //     bit 0 = 1 -> có dữ liệu
    //
    // Khi CPU đọc DATA, data_valid được clear.
    // =========================================================

    reg [7:0] uart_rx_buffer;
    reg uart_rx_data_valid;


    always @(posedge clk or negedge cpu_rst_n) begin

        if (!cpu_rst_n) begin

            uart_rx_buffer     <= 8'd0;
            uart_rx_data_valid <= 1'b0;

        end

        else begin

            // Nhận byte mới từ UART
            if (uart_rx_ready) begin

                uart_rx_buffer     <= uart_rx_data;
                uart_rx_data_valid <= 1'b1;

            end

            // CPU đọc dữ liệu -> clear valid
            if (mem_valid &&
                !mem_ready &&
                mem_uart_rx_data_en &&
                !(|mem_wstrb)) begin

                uart_rx_data_valid <= 1'b0;

            end

        end

    end


    // =========================================================
    // 9. GPIO LED
    // =========================================================

    wire gpio_wr_en;

    assign gpio_wr_en =
        mem_valid &&
        !mem_ready &&
        mem_led_en &&
        (|mem_wstrb);


    gpio u_gpio (
        .clk(clk),
        .rst_n(cpu_rst_n),

        .wr_en(gpio_wr_en),
        .wdata(mem_wdata),

        .gpio_out(led)
    );


    // =========================================================
    // 10. CNN INPUT BUFFER SIGNALS
    // =========================================================

    wire cnn_input_wr_en;

    reg buffer_clear;
    reg [9:0] buffer_read_addr;

    wire [9:0] buffer_actual_read_addr;
    wire [7:0] buffer_read_data;
    wire [9:0] buffer_write_count;


    // Chỉ ghi 1 lần cho mỗi giao dịch CPU
    assign cnn_input_wr_en =
        mem_valid &&
        !mem_ready &&
        mem_cnn_input_en &&
        (|mem_wstrb);


    // =========================================================
    // 11. CNN ACCELERATOR SIGNALS
    // =========================================================

    reg cnn_start;

    wire cnn_busy;
    wire cnn_done;

    wire [31:0] cnn_result;

    wire [9:0] cnn_pixel_addr;
    wire [7:0] cnn_pixel_data;


    // =========================================================
    // 12. BUFFER ADDRESS MUX
    // =========================================================

    assign buffer_actual_read_addr =
        cnn_busy ? cnn_pixel_addr : buffer_read_addr;


    // =========================================================
    // 13. CNN INPUT BUFFER
    // =========================================================

    cnn_input_buffer u_input_buffer (
        .clk(clk),
        .rst_n(cpu_rst_n),

        .clear(buffer_clear),

        .write_en(cnn_input_wr_en),
        .write_data(mem_wdata[7:0]),

        .read_addr(buffer_actual_read_addr),
        .read_data(buffer_read_data),

        .write_count(buffer_write_count),

        .full()
    );


    // =========================================================
    // 14. BUFFER -> CNN
    // =========================================================

    assign cnn_pixel_data = buffer_read_data;


    // =========================================================
    // 15. CNN ACCELERATOR
    // =========================================================

    cnn_accelerator u_cnn (
        .clk(clk),
        .rst_n(cpu_rst_n),

        .start(cnn_start),

        .busy(cnn_busy),
        .done(cnn_done),

        .pixel_addr(cnn_pixel_addr),
        .pixel_data(cnn_pixel_data),

        .result(cnn_result)
    );


    // =========================================================
    // 16. MEMORY READ DATA MUX
    // =========================================================

    always @(*) begin

        mem_rdata = 32'h00000000;


        // ROM
        if (mem_rom_en)
            mem_rdata = rom_rdata;


        // RAM
        else if (mem_ram_en)
            mem_rdata = ram_rdata;


        // UART RX DATA
        else if (mem_uart_rx_data_en)
            mem_rdata = {24'd0, uart_rx_buffer};


        // UART RX STATUS
        else if (mem_uart_rx_status_en)
            mem_rdata = {31'd0, uart_rx_data_valid};


        // CNN STATUS
        else if (mem_cnn_status_en)
            mem_rdata = {30'd0, cnn_busy, cnn_done};


        // CNN RESULT
        else if (mem_cnn_result_en)
            mem_rdata = cnn_result;


        // BUFFER READ ADDRESS
        else if (mem_buffer_addr_en)
            mem_rdata = {22'd0, buffer_read_addr};


        // BUFFER READ DATA
        else if (mem_buffer_data_en)
            mem_rdata = {24'd0, buffer_read_data};


        // BUFFER STATUS
        else if (mem_buffer_status_en)
            mem_rdata = {22'd0, buffer_write_count};

    end


    // =========================================================
    // 17. BUS CONTROLLER
    // =========================================================

    reg buffer_addr_wait;


    always @(posedge clk) begin

        if (!cpu_rst_n) begin

            mem_ready <= 1'b0;

            uart_wr_en <= 1'b0;

            cnn_start <= 1'b0;

            buffer_clear <= 1'b0;

            buffer_read_addr <= 10'd0;

            buffer_addr_wait <= 1'b0;

        end

        else begin

            // =================================================
            // DEFAULT
            // =================================================

            mem_ready <= 1'b0;

            uart_wr_en <= 1'b0;

            cnn_start <= 1'b0;

            buffer_clear <= 1'b0;


            // =================================================
            // PROCESS MEMORY TRANSACTION
            // =================================================

            if (mem_valid && !mem_ready) begin


                // =============================================
                // ROM
                // =============================================

                if (mem_rom_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // RAM
                // =============================================

                else if (mem_ram_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // GPIO LED
                // =============================================

                else if (mem_led_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // UART TX
                // =============================================

                else if (mem_uart_tx_en) begin

                    if (|mem_wstrb) begin

                        if (!uart_tx_busy) begin

                            uart_wr_en <= 1'b1;

                            mem_ready <= 1'b1;

                        end

                    end

                    else begin

                        mem_ready <= 1'b1;

                    end

                end


                // =============================================
                // UART RX DATA
                // =============================================

                else if (mem_uart_rx_data_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // UART RX STATUS
                // =============================================

                else if (mem_uart_rx_status_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // CNN CONTROL
                // =============================================

                else if (mem_cnn_ctrl_en) begin

                    if (|mem_wstrb) begin

                        if (mem_wdata[0])
                            cnn_start <= 1'b1;

                    end

                    mem_ready <= 1'b1;

                end


                // =============================================
                // CNN STATUS
                // =============================================

                else if (mem_cnn_status_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // CNN RESULT
                // =============================================

                else if (mem_cnn_result_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // CNN INPUT WRITE
                // =============================================

                else if (mem_cnn_input_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // BUFFER CONTROL
                // =============================================

                else if (mem_buffer_ctrl_en) begin

                    if (|mem_wstrb) begin

                        if (mem_wdata[0])
                            buffer_clear <= 1'b1;

                    end

                    mem_ready <= 1'b1;

                end


                // =============================================
                // BUFFER READ ADDRESS
                //
                // Buffer sử dụng synchronous read,
                // nên cần chờ thêm 1 chu kỳ.
                // =============================================

                else if (mem_buffer_addr_en) begin

                    if (|mem_wstrb) begin

                        if (!buffer_addr_wait) begin

                            buffer_read_addr <= mem_wdata[9:0];

                            buffer_addr_wait <= 1'b1;

                        end

                        else begin

                            buffer_addr_wait <= 1'b0;

                            mem_ready <= 1'b1;

                        end

                    end

                    else begin

                        mem_ready <= 1'b1;

                    end

                end


                // =============================================
                // BUFFER READ DATA
                // =============================================

                else if (mem_buffer_data_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // BUFFER STATUS
                // =============================================

                else if (mem_buffer_status_en) begin

                    mem_ready <= 1'b1;

                end


                // =============================================
                // INVALID ADDRESS
                // =============================================

                else begin

                    mem_ready <= 1'b1;

                end

            end


            // =================================================
            // RESET BUFFER READ WAIT STATE
            // =================================================

            else if (!mem_valid) begin

                buffer_addr_wait <= 1'b0;

            end

        end

    end

endmodule